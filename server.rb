require 'java'
require 'jruby/core_ext'
require 'stringio'
require 'bundler/setup'
Bundler.require

Dotenv.load

java_import 'ratpack.server.RatpackServer'

java_import 'ratpack.registry.Registry'
java_import 'ratpack.exec.Blocking'
java_import 'ratpack.stream.Streams'
java_import 'ratpack.http.ResponseChunks'
java_import 'java.time.Duration'

producer = Kafka::KafkaProducer.new({
  bootstrap_servers: "#{ENV['KAFKA_HOST']}:#{ENV['KAFKA_PORT']}",
  key_serializer:    "org.apache.kafka.common.serialization.StringSerializer",
  value_serializer:  "org.apache.kafka.common.serialization.StringSerializer "
})

RatpackServer.start do |b|
  b.handlers do |chain|
    chain.get do |ctx|
      ctx.render("Hello from Ratpack JRuby")
    end

    chain.get("kafka") do |ctx|
      consumer = Kafka::KafkaConsumer.new({
        bootstrap_servers:  "#{ENV['KAFKA_HOST']}:#{ENV['KAFKA_PORT']}",
        key_deserializer:   "org.apache.kafka.common.serialization.StringDeserializer",
        value_deserializer: "org.apache.kafka.common.serialization.StringDeserializer ",
        group_id: "ratpack2",
        enable_auto_commit: "false",
        auto_offset_reset:  "earliest"
      })

      consumer.subscribe(java.util.Arrays.as_list("test", "slug"))
      consumer.assign([partition])
      consumer.seek_to_beginning(partition)
      records = consumer.poll(0)
      records.each do |record|
        puts record.to_string
      end

      ctx.render("List Topics: #{consumer.list_topics}\nRecords: #{records.count}")
    end

    chain.post("logs") do |ctx|
      request = ctx.get_request
      message_count = request.get_headers.get("Logplex-Msg-Count")
      request.get_body.then do |body|
        parser = Syslog::Parser.new(allow_missing_structured_data: true)
        puts "Logplex Message Count: #{message_count}"
        messages = []
        begin
          stream = Syslog::Stream.new(
            Syslog::Stream::OctetCountingFraming.new(StringIO.new(body.get_text)),
            parser: Syslog::Parser.new(allow_missing_structured_data: true)
          )
          messages = stream.messages.to_a
        rescue Syslog::Parser::Error
          $stderr.puts "Could not parse: #{body.get_text}"
        end

        messages.each do |message|
          puts "MSG: #{message}"
        end

        #producer.connect
        #producer.send_msg("test", 0, nil, message.inspect)
        #producer.producer.flush
      end

      response = ctx.get_response
      response.status(202)
      response.send("Success")
    end
  end
end
