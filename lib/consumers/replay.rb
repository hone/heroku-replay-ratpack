require 'java'
require 'json'
require 'net/http'
require 'bundler/setup'
require 'kafka'
require 'jbundler'
require_relative '../route'
require_relative '../route_metrics'
require_relative '../kafka_options'

java_import "ratpack.http.client.HttpClient"
java_import "io.netty.buffer.PooledByteBufAllocator"
java_import "ratpack.server.ServerConfig"
java_import "ratpack.exec.internal.DefaultExecController"

consumer = Kafka.new(KafkaOptions.default).consumer(group_id: "replay")
consumer.subscribe("router", default_offset: :latest)

client = HttpClient.httpClient(PooledByteBufAllocator::DEFAULT, ServerConfig::DEFAULT_MAX_CONTENT_LENGTH)
controller = DefaultExecController.new
puts "Consuming"

consumer.each_message do |message|
  json  = JSON.parse(message.value)
  route = Route.new(json)
  puts "Processing: #{message.offset}, #{route.path}"

  controller.fork.start do
    client.get(java.net.URI.new("#{ENV['REPLAY_HOST']}/#{route.path}")).then do |response|
      puts response.get_body.get_text
    end
  end
end
