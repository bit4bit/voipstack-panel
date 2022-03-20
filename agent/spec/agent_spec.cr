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
           function handle_panel_command(command) {
                    dispatch(command)
           }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.handle_panel_command({"action" => "test"})
    runtime.pull_event?.should eq({"action" => "test"})
  end

  it "dispatch message" do
    jscore = <<-JS
           function version() {
                    return 999;
           }

           function handle_softswitch_event(source, event) {
                    event.added = 'test';
                    dispatch(event);
                    }
    JS
    runtime = Voipstack::Agent::Runtime.new(jscore)
    runtime.handle_softswitch_event("test", {"name" => "test"})
    
    runtime.pull_event?.should eq({"name" => "test", "added" => "test"})
    runtime.pull_event?.should eq(nil)
  end
end
