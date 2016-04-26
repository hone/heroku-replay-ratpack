require 'json'
require 'bundler/setup'
require 'kafka'
require 'redis'
require_relative '../route'
require_relative '../route_metrics'
require_relative '../kafka_options'

consumer = Kafka.new(KafkaOptions.default).consumer(group_id: "metrics")
consumer.subscribe("router", default_offset: :earliest)

redis   = Redis.new(url: ENV['REDIS_URL'])
metrics = RouteMetrics.new(redis)

puts "Consuming"

consumer.each_batch do |batch|
  consumer.stop
  puts batch.messages.count
  batch.messages.each do |message|
    json  = JSON.parse(message.value)
    route = Route.new(json)
    puts "Processing: #{route.path}"
    metrics.insert(route)
  end
end
