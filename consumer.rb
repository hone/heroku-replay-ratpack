require 'json'
require 'bundler/setup'
require 'kafka'
require 'redis'

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

consumer = Kafka.new(kafka_options).consumer(group_id: "average")
consumer.subscribe("router", default_offset: :earliest)

redis = Redis.new(url: ENV['REDIS_URL'])

puts "Consuming"

t = Thread.new {
  consumer.each_batch do |batch|
    consumer.stop
    puts batch.messages.count
    batch.messages.each do |message|
      json = JSON.parse(message.value)
      md   = RouterRegex.match(json["msg"])
      path = md[:path]

      puts "Processing: #{path}"

      redis.sadd "routes", path

      [:service, :connect, :wait].each do |metric|
        value = md[metric].to_i
        key   = "#{path}::#{metric}"
        redis.incrby "#{key}::sum", value
        redis.incr "#{key}::count"
        redis.set "#{key}::average", redis.get("#{key}::sum").to_i / redis.get("#{key}::count").to_f
      end
    end
  end
}

t.join
