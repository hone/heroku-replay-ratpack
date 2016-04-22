require 'json'
require 'bundler/setup'
require 'kafka'

def ssl_options
  if ENV['KAFKA_CLIENT_CERT'] &&
      ENV['KAFKA_CLIENT_CERT_KEY'] &&
      ENV['KAFKA_TRUSTED_CERT']
    {
      ssl_client_cert:      ENV['KAFKA_CLIENT_CERT'],
      ssl_client_cert_key:  ENV['KAFKA_CLIENT_CERT_KEY'],
      ssl_ca_cert:          ENV['KAFKA_TRUSTED_CERT']
    }
  else
    {}
  end
end

def kafka_options
  {
    seed_brokers: ENV['KAFKA_URL']
  }.merge(ssl_options)
end

RouterRegex = %r{
  (?<method>GET|POST){0}
  (?<path>.*){0}
  (?<host>.*){0}
  (?<fwd>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}){0}
  (?<dyno>[a-zA-Z]+\.[0-9]+){0}
  (?<queue>\d+){0}
  (?<wait>\d+){0}
  (?<connect>\d+){0}
  (?<service>\d+){0}
  (?<status>\d+){0}
  (?<bytes>\d+){0}

  ^at=info\smethod=\g<method>\spath="\g<path>"\shost=\g<host>\sfwd=["']?\g<fwd>["']?\sdyno=\g<dyno>\s(queue=\g<queue>\s)?(wait=\g<wait>ms\s)?connect=\g<connect>ms\sservice=\g<service>ms\sstatus=\g<status>\sbytes=\g<bytes>$
}x

consumer = Kafka.new(kafka_options).consumer(group_id: "foobar")
consumer.subscribe("router", default_offset: :earliest)

puts "Consuming"
t = Thread.new {
  consumer.each_batch do |batch|
    consumer.stop
    puts batch.messages.count
    batch.messages.each do |message|
      json = JSON.parse(message.value)
      puts json

      md = RouterRegex.match(json["msg"])
      puts md[:path]
      puts md[:bytes]
    end
  end
}

consumer.stop
t.join
