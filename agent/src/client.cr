require "http/client"
require "log"

require "freeswitch-esl"

require "./agent"

module Voipstack::Agent
  class Client
    @pending_events : Channel(Voipstack::Agent::Event)
    @done = Channel(Nil).new

    def initialize(@runtime : Runtime,
                   @client_url : URI,
                   @runtime_scheduler : Runtime::Scheduler = RuntimeScheduler::Timer.new(500.millisecond)
                  )
      @pending_events = Channel(Voipstack::Agent::Event).new(2048)
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

          sleep 100.milliseconds
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

  class FreeswitchInbound
    def initialize(@client : Client, @host : String, @port : Int32, @pass : String)
    end

    def run
      esl = new_esl_connection(1.seconds)
      
      if !esl.connect(1.seconds)
        raise "fails to connect please review connection or credentials"
      end
      Log.debug {"connected to freeswitch #{@host}"}

      esl.set_events("HEARTBEAT CHANNEL_CALLSTATE CUSTOM sofia::register sofia::unregister")

      events = esl.events
      loop do
        event = events.receive
        next if event.headers["content-type"] != "text/event-json"

        # obtener estado de extension desde instancia
        registrations_data = esl.api "show registrations as json"
        channels_data = esl.api "show channels as json"
        
        # generar nuevo estado
        new_state = Voipstack::Agent::Softswitch::FreeswitchState.new()
        new_state.handle_registrations_from_json(registrations_data)
        new_state.handle_channels_from_json(channels_data)

        Log.debug { "handling new freeswitch state" }
        @client.handle_softswitch_state(new_state)
      end
    end

    private def new_esl_connection(timeout : Time::Span)
      socket = TCPSocket.new(@host, @port, timeout)
      conn = ::Freeswitch::ESL::Connection.new(socket, spawn_receiver: false)

      spawn name: "freeswitch inbound esl handler" do
        conn.run
      rescue ex
        STDERR.puts(ex.inspect_with_backtrace)
        exit 1
      end
      

      ::Freeswitch::ESL::Inbound.new(conn, @pass)
    end
  end
end
