require "yaml"
require "option_parser"
require "./client"
require "log"

Log.setup_from_env

config_path = "/etc/vop-agent.yml"
CORE_PATH = "/etc/vop-agent.js"

class Config
  include YAML::Serializable

  property core_path : String = CORE_PATH
  property client_uuid : String
  property backend_endpoint_url : String
  property freeswitch_host : String
  property freeswitch_port : Int32
  property freeswitch_pass : String

  def self.from_file(path : String)
    data = File.read(path)
    self.from_yaml(data)
  end
end

OptionParser.parse do |parser|
  parser.banner = "best freeswitch panel"

  parser.on "-h", "--help", "help" do
    puts parser
    exit 1
  end

  parser.on "-c PATH", "--config=PATH", "CONFIG FILE" do |path|
    config_path = path
  end
end


# main
Log.debug { "loading config from #{config_path} " }
config = Config.from_file(config_path)

runtime = Voipstack::Agent::Runtime.from_file(config.core_path)
backend_url = URI.parse(config.backend_endpoint_url + "/agent/" + config.client_uuid + "/realtime")
scheduler = Voipstack::Agent::RuntimeScheduler::Timer.new(1.second)
client = Voipstack::Agent::Client.new(
  runtime: runtime,
  runtime_scheduler: scheduler,
  client_url: backend_url)
fs = Voipstack::Agent::FreeswitchInbound.new(
  client,
  config.freeswitch_host,
  config.freeswitch_port,
  config.freeswitch_pass
)

spawn name: "client" do
  client.run
rescue ex
  STDERR.puts(ex.inspect_with_backtrace)
  exit 1
end

puts "Started :)"
fs.run
