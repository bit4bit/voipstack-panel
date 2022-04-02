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

class AgentClientTest
  getter :runtime
  getter :http_server
  getter :client
  getter :fsserver

  def initialize(jscore : String)
    @runtime = Voipstack::Agent::Runtime.new(jscore)
    @http_server = HTTPTestServer.new()
    client_uuid = "123"
    client_url = URI.parse("http://127.0.0.1:#{@http_server.port}/agent/#{client_uuid}/realtime")
    @client = Voipstack::Agent::Client.new(runtime, client_url)
    @fsserver = Voipstack::Agent::FreeswitchInteractive.new(client)
  end

  def close
    @client.close
    @http_server.close
  end
end

describe "corejs" do
  jscore = load_core_js()

  it "detect version" do
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.version.should eq(333)
  end

  it "dispatch softswitch state extensions" do
    agent_test = AgentClientTest.new(jscore)

    spawn do
      agent_test.client.run
    end

    fsstate = Voipstack::Agent::Softswitch::FreeswitchState.new()
    fsstate.handle_registrations_from_json(%({"row_count":4,"rows":[{"reg_user":"2903","realm":"voipstack99.voipstack.com","token":"jk9a9jc3f8e1hjlh6eg27h","url":"sofia/hub.voipstack.com/sip:u27c5j46@40d9qcmqq6i8.invalid;transport=ws;fs_nat=yes;fs_path=sip%3Au27c5j46%408.8.9.2%3A65403%3Btransport%3Dwss","expires":"1648929528","network_ip":"8.8.9.2","network_port":"65403","network_proto":"udp","hostname":"1.2.3.4","metadata":""},{"reg_user":"3207","realm":"voipstack99.voipstack.com","token":"ge3cf03igdcv79tpfd9rt2","url":"sofia/hub.voipstack.com/sip:vhffl9ah@vof777525ddl.invalid;transport=ws;fs_nat=yes;fs_path=sip%3Avhffl9ah%408.8.9.2%3A49524%3Btransport%3Dwss","expires":"1648930745","network_ip":"8.8.9.2","network_port":"49524","network_proto":"udp","hostname":"1.2.3.4","metadata":""},{"reg_user":"3219","realm":"voipstack99.voipstack.com","token":"nte2gh37b76s2ogepnphud","url":"sofia/hub.voipstack.com/sip:7geei169@tcs2gcmi299b.invalid;transport=ws;fs_nat=yes;fs_path=sip%3A7geei169%408.8.9.2%3A49940%3Btransport%3Dwss","expires":"1648931091","network_ip":"8.8.9.2","network_port":"49940","network_proto":"udp","hostname":"1.2.3.4","metadata":""},{"reg_user":"3205","realm":"voipstack99.voipstack.com","token":"6qa482575j664sfubc7e0e","url":"sofia/hub.voipstack.com/sip:t7124lu4@gme229qug6mt.invalid;transport=ws;fs_nat=yes;fs_path=sip%3At7124lu4%408.8.9.2%3A49499%3Btransport%3Dwss","expires":"1648931176","network_ip":"8.8.9.2","network_port":"49499","network_proto":"udp","hostname":"1.2.3.4","metadata":""}]}))
    
    agent_test.fsserver.dispatch_softswitch_state(fsstate)
    agent_test.fsserver.dispatch_event(Voipstack::Agent::Event.new("platform", {"action" => "refresh-state"}))

    exc = trap_exception do
      select
      when req = agent_test.http_server.requests.receive
        ev = {
          "source" => "freeswitch",
          "content" => {
            "extensions" => [
              {
                "id" => "2903@voipstack99.voipstack.com",
                "name" => "2903",
                "realm" => "voipstack99.voipstack.com"
              },
              {
                "id" => "3207@voipstack99.voipstack.com",
                "name" => "3207",
                "realm" => "voipstack99.voipstack.com"
              },
              {
                "id" => "3219@voipstack99.voipstack.com",
                "name" => "3219",
                "realm" => "voipstack99.voipstack.com"
              },
              {
                "id" => "3205@voipstack99.voipstack.com",
                "name" => "3205",
                "realm" => "voipstack99.voipstack.com"
              }
            ]
          }
        }
        
        req.body.should eq(ev.to_json)
      when timeout 1.second
        raise "timeout"
      end
    end

    agent_test.close
    exc.should eq(nil)
  end
  
  it "dispatch softswitch state from runtime" do
    agent_test = AgentClientTest.new(jscore)

    spawn do
      agent_test.client.run
    end

    agent_test.fsserver.dispatch_event(Voipstack::Agent::Event.new("test", {"name" => "test"}))

    exc = trap_exception do
      select
      when req = agent_test.http_server.requests.receive
        req.body.should eq("{\"source\":\"freeswitch\",\"content\":{\"name\":\"test\"}}")
      when timeout 1.second
        raise "timeout"
      end
    end

    agent_test.close

    exc.should eq(nil)
  end
end
