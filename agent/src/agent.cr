# VOIPSTACK --- Software Libre voip solutions
# Copyright © 2022 Jovany Leandro G.C <bit4bit@riseup.net>
#
#
# This file is part of VOIPSTACK.
#
# VOIPSTACK is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# VOIPSTACK is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with VOIPSTACK. If not, see <https://www.gnu.org/licenses/>.

require "duktape"
require "duktape/runtime"
require "json"

module Voipstack::Agent
  VERSION = "0.1.0"

  alias Call = Hash(String, Array(String) | String)
  alias Calls = Hash(String, Call)
  alias Extension = Hash(String, String)
  alias Extensions = Hash(String, Extension)

  alias EventValue = String | Hash(String, String) | Extensions | Calls
  alias EventContent = Hash(String, EventContent) | String | Hash(String, String) | Extensions | Calls

  alias SoftswitchSource = String
  alias Command = Array(String)

  alias EventGeneric = Hash(String, String | Hash(String, String | Hash(String, Array(String) | String)) | Array(String)) | Hash(String, String)

  class EventState
    include JSON::Serializable

    getter :extensions
    getter :calls
    def initialize(@calls = Calls.new, @extensions = Extensions.new)
    end
  end

  class Event
    include JSON::Serializable

    getter :source
    getter :content

    def initialize(@source : SoftswitchSource, @content : EventGeneric)
    end

    def hash
      [@source, @content].hash
    end

    def ==(other)
      hash == other.hash
    end
  end

  class Softswitch
    class Stater

      getter :source
      getter :calls
      getter :extensions

      def initialize(@source : SoftswitchSource, @calls = Calls.new, @extensions = Extensions.new)
        super()
      end

      def to_json : String
        {"calls" => @calls,
         "extensions" => @extensions}.to_json()
      end
    end

    class FreeswitchState < Stater
      def initialize
        super("freeswitch")
      end

      # data es obtenida usando 'show channels as json'
      # algunas consideraciones:
      # - un canal outbound con presence_id es desde una extension
      # y su b leg seria el channel cuyo call_uuid corresponde al uuid
      def handle_channels_from_json(data : String) : Calls
        record = JSON.parse(data)
        calls = Calls.new

        if record["row_count"].to_s.to_i > 0
          record["rows"].as_a.each do |row|
            aleg_uuid = row["uuid"].to_s
            call_uuid = row["call_uuid"].to_s

            next if !call_uuid.empty?
            # respecto a la extension
            logical_direction = { "inbound" => "outbound", "outbound" => "inbound" }
            direction = row["direction"].to_s

            presence_id = row["presence_id"].to_s
            calls[aleg_uuid] = {
              "id" => aleg_uuid,
              "extension_id" => row["presence_id"].to_s,
              "direction" => logical_direction[direction],
              "realm" => get_realm(presence_id),
              "caller_id_number" => row["cid_num"].to_s,
              "caller_id_name" => row["cid_name"].to_s,
              "destination" => row["dest"].to_s,
              "created_epoch" => row["created_epoch"].to_s,
              "tags" => [] of String
            }

          end

          record["rows"].as_a.each do |row|
            aleg_uuid = row["uuid"].to_s
            call_uuid = row["call_uuid"].to_s
            next if call_uuid.empty?
            # procesar cuando se encuentra la leg B
            if calls.has_key?(call_uuid)
              calls[call_uuid].merge!({
                "callstate" => row["callstate"].to_s.downcase,
                "caller_id_number" => row["cid_num"].to_s,
                "caller_id_name" => row["cid_name"].to_s,
                "callee_id_number" => row["callee_num"].to_s,
                "callee_id_name" => row["callee_name"].to_s,
              })
            end
          end
        end

        @calls = calls
      end

      def handle_registrations_from_json(data : String) : Extensions
        record = JSON.parse(data)
        extensions = Extensions.new
          
        if record["row_count"].to_s.to_i > 0
          record["rows"].as_a.each do |row|
            reg_user = row["reg_user"].to_s
            realm = row["realm"].to_s
            id = "#{reg_user}@#{realm}"

            extension = Extension.new
            extension["id"] = id
            extension["name"] = reg_user
            extension["realm"] = realm

            extensions[id] = extension
          end
        end

        @extensions = extensions
      end

      private def get_realm(presence_id : String)
        _, realm = presence_id.split("@")
        realm
      end
    end
  end

  class SoftswitchStateGetter
    def state : Voipstack::Agent::Softswitch::Stater?
    end
  end
  
  class SoftswitchStateGetterDumb < SoftswitchStateGetter
    def state
      nil
    end
  end
  class SoftswitchStateGetterInMemory < SoftswitchStateGetter
    getter :state
    def initialize(@state : Voipstack::Agent::Softswitch::Stater)
    end
  end

  # Runtime hace dinamica la logica del agente
  # esto con el proposito de actualizar en tiempo de ejecucion el core.
  class Runtime
    @js_mutex = Mutex.new

    # El oscilador del runtime
    class Scheduler
      def install(runtime : Runtime) : Channel(Exception?)
        raise NotImplementedError.new("install")
      end
    end

    def self.from_file(path : String)
      script = File.read(path)
      self.new(script)
    end

    def initialize(jscore : String)
      @js = Duktape::Runtime.new
      @js.exec <<-JS
               var _dispatch_events = [];

               function dispatch(source, event) {
                        _dispatch_events.push({"source": source, "content": event})
               }

               // NOTE(bit4bit) requerimos este envolvente ya que duktape
               // no codifica objetos recursivos de crystal
               function _unserialize_handle_softswitch_state(source, data) {
                        var _event = JSON.parse(data);
                        return handle_softswitch_state(source, _event);
               }
      JS
      @js.exec jscore

      # TODO(bit4bit) verificar que jscore
      # tiene las funciones esperadas
    end

    # evento para voipstack-panel
    def pull_event? : Event | Nil
      synchronize do
        event = @js.eval("_dispatch_events.shift()")
        if event.nil?
          nil
        else
          Event.from_json(event.to_json)
        end
      end
    end

    # se ejecuta frecuentemente
    def handle_softswitch_state(state : Softswitch::Stater)
      synchronize do
        @js.call("_unserialize_handle_softswitch_state", state.source, state.to_json)
      end
    end

    # comando enviado por el servidor al agente
    def handle_panel_command(cmd : String, arg : String)
      synchronize do
        @js.call("handle_panel_command", cmd, arg)
      end
    end

    # gestionar evento de softswitch
    def handle_softswitch_event(envelop : Event)
      synchronize do
        @js.call("handle_softswitch_event", envelop.source, envelop.content)
      end
    end
    def handle_softswitch_event(source : SoftswitchSource, event : EventGeneric)
      synchronize do
        @js.call("handle_softswitch_event", source, event)
      end
    end

    private def synchronize
      @js_mutex.synchronize do
        yield
      end
    end
    def version : Int32
      version = @js.call("version")

      if version.nil?
        0
      else
        version.as(Float64).to_i
      end
    end
  end

  
  class RuntimeScheduler::Timer < Runtime::Scheduler
    def initialize(@tick : Time::Span)
    end
    def install(runtime : Runtime)
      done = Channel(Exception?).new(1)

      spawn name: "RuntimeScheduler::Timer" do
        loop do
          select
          when timeout @tick
            runtime.handle_softswitch_state(Softswitch::FreeswitchState.new())
          end
        end
      rescue exc
        done.send exc
      else
        done.send nil
      end

      done
    end
  end

  class RuntimeScheduler::Interactive < Runtime::Scheduler
    def install(runtime : Runtime::Scheduler) : Exception?
      runtime.handle_softswitch_state(Softswitch::FreeswitchState.new())
    end
  end
end

require "./client.cr"
