require "http/client"

module Voipstack::Agent
  
  class Client

    def initialize(runtime : Runtime,
                   client_url : URI)
      @runtime = runtime
      @client_url = client_url
    end

    def dispatch_event(event : Event)
      http_dispatch_event(event)
    end

    private def http_dispatch_event(event : Event)
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
  end


end
