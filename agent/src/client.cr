require "http/client"

module Voipstack::Agent
  class Client
    @pending_events = Channel(Event).new(2048)
    @done = Channel(Nil).new

    def initialize(@runtime : Runtime,
                   @client_url : URI,
                   @runtime_scheduler : Runtime::Scheduler = RuntimeScheduler::Timer.new(500.millisecond)
                  )
    end

    def dispatch_event(event : Event)
      @pending_events.send event
    end

    def handle_softswitch_state(state : Softswitch::Stater)
      @runtime.handle_softswitch_state(state)
    end
    
    def run
      done_runtime = @runtime_scheduler.install(@runtime)

      loop do
        select # al finilizar el oscilador detenemos cliente

        when exc = done_runtime.receive
          if !exc.nil?
            raise exc
          end
          break
        when @done.receive
          break
        when event = @pending_events.receive
          @runtime.handle_softswitch_event(event)
        else
          # emitimos eventos del procesador runtime
          runtime_event = @runtime.pull_event?
          if !runtime_event.nil?
            http_dispatch_event(runtime_event)
          end
        end
      end
    end

    def close
      @done.send nil
      @pending_events.close
    end

    private def http_dispatch_event(event)
      client = HTTP::Client.new(@client_url)
      client.write_timeout = 3.second
      client.read_timeout = 3.second
      client.put(@client_url.path, nil, event.to_json)
    end
  end

  class FreeswitchInteractive
    def initialize(@client : Client)
    end

    def dispatch_event(event : Event)
      @client.dispatch_event(event)
    end

    def dispatch_softswitch_state(state : Softswitch::Stater)
      @client.handle_softswitch_state(state)
    end
  end
end
