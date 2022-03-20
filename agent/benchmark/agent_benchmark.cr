require "./benchmark_helper"

jscore = <<-JS
                  function handle_panel_command(command) {
                    dispatch(command)
           }
JS

runtime = Voipstack::Agent::Runtime.new(jscore)

Benchmark.ips do |x|
  x.report("runtime echo event") {
    runtime.handle_panel_command({"action" => "bench"})
    runtime.pull_event?
  }
end
