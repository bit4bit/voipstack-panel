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
require "cbor"

module Voipstack::Agent
  VERSION = "0.1.0"

  alias Event = Hash(String, String | Float64 | Nil)
  alias Command = Array(String)
  
  class Runtime

    def initialize(jscore : String)
      @js = Duktape::Runtime.new
      @js.exec <<-JS
               var _dispatch_events = [];

               function dispatch(event) {
                        _dispatch_events.push(event)
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
    def handle_tick()
      @js.call("handle_tick")
    end

    # comando enviado por el servidor al agente
    def handle_panel_command(cmd : String, arg : String)
      @js.call("handle_panel_command", cmd, arg)
    end
    
    # gestionar evento de softswitch
    def handle_softswitch_event(source : String, event : Event)
      @js.call("handle_softswitch_event", source, event)
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
