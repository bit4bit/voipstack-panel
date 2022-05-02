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

describe Voipstack::Agent::Runtime do
  it "detect version" do
    jscore = <<-JS
                  function version() {
                           return 999;
                  }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.version.should eq(999)
  end

  it "handle panel command" do
    jscore = <<-JS
           function handle_panel_command(cmd, arg) {
                    ret = {};
                    ret[cmd] = arg;
                    dispatch("test", ret)
           }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.handle_panel_command("action", "test")
    runtime.pull_event?.try &.content.should eq({"action" => "test"})
  end

  it "dispatch message" do
    jscore = <<-JS
           function version() {
                    return 999;
           }

           function handle_softswitch_event(source, event) {
                    event.added = 'test';
                    dispatch(source, event);
                    }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.handle_softswitch_event("test", {"name" => "test", "added" => "test"})
    
    runtime.pull_event?.as(Voipstack::Agent::Event).content.should eq({"name" => "test", "added" => "test"})
    runtime.pull_event?.should eq(nil)
  end

  it "dispatch message usin Envelop" do
    jscore = <<-JS
           function version() {
                    return 999;
           }

           function handle_softswitch_event(source, event) {
                    event.added = 'test';
                    dispatch(source, event);
                    }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.handle_softswitch_event(Voipstack::Agent::Event.new("test", {"name" => "test", "added" => "test"}))
    
    runtime.pull_event?.as(Voipstack::Agent::Event).content.should eq({"name" => "test", "added" => "test"})
    runtime.pull_event?.should eq(nil)
  end

  it "dispatch message complex" do
    jscore = <<-JS
           function version() {
                    return 999;
           }

           function handle_softswitch_event(source, event) {
                    event.added = 'test';
                    dispatch(source, event);
                    }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.handle_softswitch_event("test", {"name" => "test", "added" => "test",
                                             "nested" => {"a" => "b"},
                                             "nestednested" => {"a" => {"a" => "2"}},
                                             "list" => ["1", "2"]})
    
    runtime.pull_event?.as(Voipstack::Agent::Event).content.should eq({"name" => "test", "added" => "test",
                                                                       "nested" => {"a" => "b"},
                                                                       "nestednested" => {"a" => {"a" => "2"}},
                                                                       "list" => ["1","2"]})
    runtime.pull_event?.should eq(nil)
  end

  it "process softswitch state" do
    jscore = <<-JS
           function version() {
                    return 999;
           }

           function handle_softswitch_state(source, propertyName, propertyValue) {
                    propertyValue.added = 'test';
                    var ret = {};
                    ret[propertyName] = propertyValue;
                    dispatch(source, ret);
                    }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.handle_softswitch_state("test", "calls", {
                                                 "abc" => {
                                                   "id" => "abc",
                                                   "tags" => ["1"]
                                                 }
                                    }.to_json)
    runtime.handle_softswitch_state("test", "extensions", {
                                                 "cba" => {
                                                   "id" => "cba"
                                                 }
                                               }.to_json)
    
    runtime.pull_event?.as(Voipstack::Agent::Event).content.should eq(
                                                              {"calls" => {"abc" => {"id" => "abc", "tags" => ["1"]}, "added" => "test"}})
    runtime.pull_event?.as(Voipstack::Agent::Event).content.should eq(
                                                              {"extensions" => {"cba" => {"id" => "cba"}, "added" => "test",
                                                               "added" => "test"}})
    runtime.pull_event?.should eq(nil)
  end

end
