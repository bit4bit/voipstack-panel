require "duktape"
require "duktape/runtime"
require "cbor"

module Voipstack::Agent
  VERSION = "0.1.0"

  alias Event = Hash(String, String | Float64 | Nil)
  alias Command = Hash(String, String | Float64 | Nil)
  
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

    def handle_panel_command(cmd : Command)
      @js.call("handle_panel_command", cmd)
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
