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
    class Stater < Hash(String, EventValue)
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

  # Runtime hace dinamica la logica del agente
  # esto con el proposito de actualizar en tiempo de ejecucion el core.
  class Runtime
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
end

require "./client.cr"
