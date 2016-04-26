require 'java'
require 'jruby/core_ext'
require 'stringio'
require 'json'
require 'bundler/setup'
require 'jbundler'
require 'syslog/parser'
require 'syslog/stream'
require 'kafka'
require 'connection_pool'

require_relative 'kafka_options'

java_import 'ratpack.server.RatpackServer'
java_import 'ratpack.exec.Blocking'

$kafka_pools = {
  producer: ConnectionPool.new(size: 20, timeout: 5) { Kafka.new(KafkaOptions.default).async_producer },
  consumer: ConnectionPool.new(size: 5, timetou: 5) { Kafka.new(KafkaOptions.default).consumer(group_id: "ratpack") }
}

RatpackServer.start do |b|
  b.handlers do |chain|
    chain.get do |ctx|
      ctx.render("Hello from Ratpack JRuby")
    end

    chain.get("kafka") do |ctx|
      $kafka_pools[:consumer].with do |consumer|
        consumer = kafka_consumer_pool
        consumer.subscribe("router")

        Blocking.get do
          messages = nil

          consumer.each_batch(max_wait_time: 1) do |batch|
            consumer.stop
            messages = batch.messages
            puts "Hello Bro"
            messages.each do |message|
              puts message.inspect
            end
          end

          messages || []
        end.then do |messages|
          ctx.render("Messages: #{messages.size}")
        end
      end
    end

    chain.post("process") do |ctx|
      request = ctx.get_request
      request.get_body.then do |body|
        process_messages(body.get_text)

        response = ctx.get_response
        response.status(202)
        ctx.render("Accepted")
      end
    end

    chain.post("logs") do |ctx|
      request  = ctx.get_request
      response = ctx.get_response
      message_count = request.get_headers.get("Logplex-Msg-Count")
      request.get_body.then do |body|
        puts "Logplex Message Count: #{message_count}"
        puts body.get_text
        response.send("Success")
      end

      response.status(200)
    end
  end
end

def process_messages(body_text)
  messages = []
  begin
    stream = Syslog::Stream.new(
      Syslog::Stream::OctetCountingFraming.new(StringIO.new(body_text)),
      parser: Syslog::Parser.new(allow_missing_structured_data: true)
    )
    messages = stream.messages.to_a
  rescue Syslog::Parser::Error
    $stderr.puts "Could not parse: #{body_text}"
  end

  $kafka_pools[:producer].with do |producer|
    producer = Kafka.new(KafkaOptions.default).async_producer
    messages.each do |message|
      producer.produce(message.to_h.to_json, topic: message.procid) if message.procid == "router"
    end

    producer.deliver_messages
  end
rescue
  $stderr.puts $!
end
