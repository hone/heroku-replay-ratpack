class Route
  Regex = %r{
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

  attr_reader :timestamp

  def initialize(json)
    @timestamp = Time.parse(json["timestamp"])
    @message   = Regex.match(json["msg"])
  end

  def method_missing(*args)
    @message[args[0]]
  rescue
    $stderr.puts "Missing Key: #{args[0]} is not in #{@message.inspect}"
  end
end
