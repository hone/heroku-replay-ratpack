require 'json'
require 'net/http'
require 'bundler/setup'
require 'kafka'
require 'concurrent'
require_relative '../route'
require_relative '../route_metrics'
require_relative '../kafka_options'

consumer = Kafka.new(KafkaOptions.default).consumer(group_id: "replay")
consumer.subscribe("router", default_offset: :latest)

puts "Consuming"

consumer.each_batch do |batch|
  puts batch.messages.count
  batch.messages.each do |message|
    json  = JSON.parse(message.value)
    route = Route.new(json)
    puts "Processing: #{route.path}"

    Concurrent::Promise.execute { Net::HTTP.get(ENV['REPLAY_HOST'], route.path) }.then {|response| puts response }
  end
end
