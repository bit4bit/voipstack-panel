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

  alias EventValue = String | Float64 | Nil
  alias EventContent = Hash(String, EventValue) | Hash(String, String)
  alias EventSource = String
  alias Command = Array(String)

  class Event
    include JSON::Serializable

    getter :source
    getter :content

    def initialize(@source : EventSource, @content : EventContent)
    end
  end

  class Softswitch
    alias StateType = Hash(String, EventValue)
    class Stater < StateType
      def initialize(source : String)
        super()
        self["source"] = source
      end
    end

    class FreeswitchState < Stater
      def initialize
        super("freeswitch")
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

    # El oscilador del runtime
    class Scheduler
      def install(runtime : Runtime) : Channel(Exception?)
        raise NotImplementedError.new("install")
      end
    end

    def initialize(jscore : String)
      @js = Duktape::Runtime.new
      @js.exec <<-JS
               var _dispatch_events = [];

               function dispatch(source, event) {
                        _dispatch_events.push({"source": source, "content": event})
               }
      JS
      @js.exec jscore

      # TODO(bit4bit) verificar que jscore
      # tiene las funciones esperadas
    end

    # evento para voipstack-panel
    def pull_event? : Event | Nil
      event = @js.eval("_dispatch_events.shift()")
      if event.nil?
        nil
      else
        Event.from_json(event.to_json)
      end
    end

    # se ejecuta frecuentemente
    def handle_softswitch_state(state : Softswitch::Stater)
      @js.call("handle_softswitch_state", state)
    end

    # comando enviado por el servidor al agente
    def handle_panel_command(cmd : String, arg : String)
      @js.call("handle_panel_command", cmd, arg)
    end

    # gestionar evento de softswitch
    def handle_softswitch_event(event : Event)
      @js.call("handle_softswitch_event", event.source, event.content)
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
      done = Channel(Exception?).new()

      spawn name: "RuntimeScheduler::Timer" do
        loop do
          select # TODO(bit4bit) tick time configurable
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
