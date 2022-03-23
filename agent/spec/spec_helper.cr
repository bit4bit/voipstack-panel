# VOIPSTACK --- Software Libre voip solutions
# Copyright © 2022 Jovany Leandro G.C <bit4bit@riseup.net>
#
#
# This file is part of VOIPSTACK.
#
# VOIPSTACK is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# VOIPSTACK is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with VOIPSTACK. If not, see <https://www.gnu.org/licenses/>.

require "spec"
require "../src/agent"
require "http/server"

def load_core_js()
  File.read("./bin/core.js")
end

class HTTPTestServer
  class Request
    getter :body

    def initialize(req : HTTP::Request)
      body = req.body
      if body.nil?
        @body = ""
      else
        @body = body.gets_to_end
      end
    end
  end

  @requests = Channel(Request).new(1)
  @port : Int32

  getter :port
  getter :requests
    
  def initialize
    @server = HTTP::Server.new do |context|
      @requests.send Request.new(context.request.dup)

      context.response.content_type = "application/json"
      context.response.print "OK"
    end

    address = @server.bind_unused_port
    @port = address.port

    started = Channel(Nil).new
    spawn do
      started.send nil
      @server.listen
    end
    started.receive
  end

  def close
    @server.close
  end
end


def trap_exception : Exception?
  begin
    yield
  rescue exc
    return exc
  else
    return nil
  end
end
