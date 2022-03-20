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
