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

    registrations_data = %({"row_count":4,"rows":[{"reg_user":"2903","realm":"voipstack99.voipstack.com","token":"jk9a9jc3f8e1hjlh6eg27h","url":"sofia/hub.voipstack.com/sip:u27c5j46@40d9qcmqq6i8.invalid;transport=ws;fs_nat=yes;fs_path=sip%3Au27c5j46%408.8.9.2%3A65403%3Btransport%3Dwss","expires":"1648929528","network_ip":"8.8.9.2","network_port":"65403","network_proto":"udp","hostname":"1.2.3.4","metadata":""},{"reg_user":"3207","realm":"voipstack99.voipstack.com","token":"ge3cf03igdcv79tpfd9rt2","url":"sofia/hub.voipstack.com/sip:vhffl9ah@vof777525ddl.invalid;transport=ws;fs_nat=yes;fs_path=sip%3Avhffl9ah%408.8.9.2%3A49524%3Btransport%3Dwss","expires":"1648930745","network_ip":"8.8.9.2","network_port":"49524","network_proto":"udp","hostname":"1.2.3.4","metadata":""},{"reg_user":"3219","realm":"voipstack99.voipstack.com","token":"nte2gh37b76s2ogepnphud","url":"sofia/hub.voipstack.com/sip:7geei169@tcs2gcmi299b.invalid;transport=ws;fs_nat=yes;fs_path=sip%3A7geei169%408.8.9.2%3A49940%3Btransport%3Dwss","expires":"1648931091","network_ip":"8.8.9.2","network_port":"49940","network_proto":"udp","hostname":"1.2.3.4","metadata":""},{"reg_user":"3205","realm":"voipstack99.voipstack.com","token":"6qa482575j664sfubc7e0e","url":"sofia/hub.voipstack.com/sip:t7124lu4@gme229qug6mt.invalid;transport=ws;fs_nat=yes;fs_path=sip%3At7124lu4%408.8.9.2%3A49499%3Btransport%3Dwss","expires":"1648931176","network_ip":"8.8.9.2","network_port":"49499","network_proto":"udp","hostname":"1.2.3.4","metadata":""}]})
    agent_test.fsserver.dispatch_softswitch_state("test", "registrations", registrations_data)
    agent_test.fsserver.dispatch_event(Voipstack::Agent::Event.new("platform", {"action" => "refresh-state"}))

    exc = trap_exception do
      select
      when req = agent_test.http_server.requests.receive
        ev = {
          "source" => "freeswitch",
          "content" => {
            "extensions" => {
              "2903voipstack99voipstackcom" => {
                "id" => "2903voipstack99voipstackcom",
                "name" => "2903",
                "realm" => "voipstack99.voipstack.com"
              },
              "3207voipstack99voipstackcom" => {
                "id" => "3207voipstack99voipstackcom",
                "name" => "3207",
                "realm" => "voipstack99.voipstack.com"
              },
              "3219voipstack99voipstackcom" => {
                  "id" => "3219voipstack99voipstackcom",
                  "name" => "3219",
                  "realm" => "voipstack99.voipstack.com"
              },
              "3205voipstack99voipstackcom" => {
                "id" => "3205voipstack99voipstackcom",
                "name" => "3205",
                "realm" => "voipstack99.voipstack.com"
              }
            },
            "calls" => Voipstack::Agent::Calls.new
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

  it "dispatch softswitch state calls" do
    agent_test = AgentClientTest.new(jscore)
    spawn do
      agent_test.client.run
    rescue ex
      exit 1
    end

    channels_data = %({
  "row_count": 2,
  "rows": [
    {
      "uuid": "bfa99eb8-c2b3-4a83-b064-b71a3a16532f",
      "direction": "inbound",
      "created": "2022-04-17 22:28:59",
      "created_epoch": "1650234539",
      "name": "sofia/hub.voipstack.com/102@demo.voipstack.com:7443",
      "state": "CS_EXECUTE",
      "cid_name": "102",
      "cid_num": "102",
      "ip_addr": "201.185.101.173",
      "dest": "555444",
      "application": "bridge",
      "application_data": "{bridge_early_media=false,effective_caller_id_number=17875391485,effective_caller_id_name=17875391485,ignore_display_updates=true,origination_callee_id_number=17875391485,origination_callee_id_name=17875391485,origination_caller_id_number=12345678,origination_caller_id_name=12345678}[]sofia/gateway/sip.vip2phone.net/9036#17875391485|error/NO_ROUTE_DESTINATION",
      "dialplan": "XML",
      "context": "demo.voipstack.com",
      "read_codec": "PCMU",
      "read_rate": "8000",
      "read_bit_rate": "64000",
      "write_codec": "PCMU",
      "write_rate": "8000",
      "write_bit_rate": "64000",
      "secure": "srtp:dtls:AES_CM_128_HMAC_SHA1_80",
      "hostname": "34.196.247.12",
      "presence_id": "102@demo.voipstack.com",
      "presence_data": "",
      "accountcode": "",
      "callstate": "EARLY",
      "callee_name": "",
      "callee_num": "",
      "callee_direction": "",
      "call_uuid": "",
      "sent_callee_name": "",
      "sent_callee_num": "",
      "initial_cid_name": "102",
      "initial_cid_num": "102",
      "initial_ip_addr": "201.185.101.173",
      "initial_dest": "555444",
      "initial_dialplan": "XML",
      "initial_context": "demo.voipstack.com"
    },
    {
      "uuid": "6098c3eb-7f3c-4b00-9fa9-7a1b21372472",
      "direction": "outbound",
      "created": "2022-04-17 22:28:59",
      "created_epoch": "1650234539",
      "name": "sofia/hub.voipstack.com/9036#12345678",
      "state": "CS_CONSUME_MEDIA",
      "cid_name": "12345678",
      "cid_num": "12345678",
      "ip_addr": "201.185.101.173",
      "dest": "9036#555444",
      "application": "",
      "application_data": "",
      "dialplan": "XML",
      "context": "demo.voipstack.com",
      "read_codec": "PCMU",
      "read_rate": "8000",
      "read_bit_rate": "64000",
      "write_codec": "PCMU",
      "write_rate": "8000",
      "write_bit_rate": "64000",
      "secure": "",
      "hostname": "34.196.247.12",
      "presence_id": "",
      "presence_data": "",
      "accountcode": "",
      "callstate": "EARLY",
      "callee_name": "98765321",
      "callee_num": "98765321",
      "callee_direction": "",
      "call_uuid": "bfa99eb8-c2b3-4a83-b064-b71a3a16532f",
      "sent_callee_name": "",
      "sent_callee_num": "",
      "initial_cid_name": "12345678",
      "initial_cid_num": "12345678",
      "initial_ip_addr": "201.185.101.173",
      "initial_dest": "9036#555444",
      "initial_dialplan": "XML",
      "initial_context": "demo.voipstack.com"
    }
  ]
})
    agent_test.fsserver.dispatch_softswitch_state("test", "channels", channels_data)
    agent_test.fsserver.dispatch_event(Voipstack::Agent::Event.new("platform", {"action" => "refresh-state"}))

    exc = trap_exception do
      select
      when req = agent_test.http_server.requests.receive
        ev = {
          "source" => "freeswitch",
          "content" => {
            "extensions" => Voipstack::Agent::Extensions.new,
            "calls" => {
              "bfa99eb8-c2b3-4a83-b064-b71a3a16532f" => {              
                "id" => "bfa99eb8-c2b3-4a83-b064-b71a3a16532f",
                "extension_id" => "102demovoipstackcom",
                "realm" => "demo.voipstack.com",
                "direction" => "outbound",
                "destination" => "555444",
                "callstate" => "early",
                "caller_id_name" => "12345678",
                "caller_id_number" => "12345678",
                "callee_id_name" => "98765321",
                "callee_id_number" => "98765321",
                "created_epoch" => "1650234539",
                "tags" => [] of String,
              }
            }
          }
        }

        Voipstack::Agent::Event.from_json(req.body.not_nil!).should eq(Voipstack::Agent::Event.from_json(ev.to_json))
      when timeout 1.second
        raise "timeout"
      end
    end

    agent_test.close
    exc.should eq(nil)
  end
end
