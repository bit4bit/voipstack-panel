require "http/client"
require "log"

require "freeswitch-esl"

require "./agent"

module Voipstack::Agent

  # Conectamos el runtime con la plataforma voipstack
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

    def handle_softswitch_state(source : SoftswitchSource, property_name : String, property_values : String)
      @runtime.handle_softswitch_state(source, property_name, property_values)
    end

    def handle_softswitch_state_property(source : SoftswitchSource, name : String, values : String)
      @runtime.handle_softswitch_state_property(source, name, values)
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
        when timeout 500.milliseconds
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
      body = event.to_json

      Log.debug { "Sending body: #{body.inspect}" }

      client.put(@client_url.path, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: body) do |response|
        if response.status_code >= 300 && response.status_code < 400
          STDERR.puts "not implemented http redirects, please hire a developer"
        elsif response.status_code >= 400
          Log.error { "http_dispatch_event got #{response.status_code} from server: #{response.body_io.gets}" }
        end
      end
    rescue ex
      STDERR.puts ex.inspect_with_backtrace
    end
  end

  
  class FreeswitchInteractive
    def initialize(@client : Client)
    end

    def dispatch_event(event : Event)
      @client.dispatch_event(event)
    end

    def dispatch_softswitch_state(source : SoftswitchSource, name : String, values : String)
      @client.handle_softswitch_state(source, name, values)
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

      loop do
        sleep 300.millisecond
        # obtener estado de extension desde instancia
        registrations_data = esl.api "show registrations as json"
        channels_data = esl.api "show channels as json"
        callcenter_queues_data = esl.api %q(json {"command": "callcenter_config", "format": "pretty", "data": {"arguments":"queue list"}})
        callcenter_tiers_data = esl.api %q(json {"command": "callcenter_config", "format": "pretty", "data": {"arguments":"tier list"}})

        # notificamos propiedas del estado
        @client.handle_softswitch_state("freeswitch", "registrations", registrations_data)
        @client.handle_softswitch_state("freeswitch", "channels", channels_data)
        @client.handle_softswitch_state("freeswitch", "callcenter_queues", callcenter_queues_data)
        @client.handle_softswitch_state("freeswitch", "callcenter_tiers", callcenter_tiers_data)
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
