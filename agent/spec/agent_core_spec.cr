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

require "./spec_helper"

describe "corejs" do
  jscore = load_core_js()

  it "detect version" do
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.version.should eq(333)
  end

  it "dispatch softswitch state from runtime" do
    runtime = Voipstack::Agent::Runtime.new(jscore)
    http_test_server = HTTPTestServer.new()
    client_uuid = "123"
    client_url = URI.parse("http://127.0.0.1:#{http_test_server.port}/agent/#{client_uuid}/realtime")
    client = Voipstack::Agent::Client.new(runtime, client_url)
    fsserver = Voipstack::Agent::FreeswitchInteractive.new(client)
    spawn do
      client.run
    end

    fsserver.dispatch_event(Voipstack::Agent::Event.new("test", {"name" => "test"}))

    exc = trap_exception do
      select
      when req = http_test_server.requests.receive
        req.body.should eq("{\"source\":\"freeswitch\",\"content\":{\"name\":\"test\"}}")
      when timeout 1.second
        raise "timeout"
      end
    end

    client.close
    http_test_server.close

    exc.should eq(nil)
  end
end
