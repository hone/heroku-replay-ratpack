require 'digest'

class RouteMetrics
  def initialize(redis)
    @redis = redis
  end

  def insert(route)
    path = route.path
    path_digest = Digest::SHA256.hexdigest(path)

    @redis.hset "routes", path, path_digest

    [:service, :connect].each do |metric|
      value = route.send(metric).to_i
      key   = "#{path_digest}::#{metric}"

      @redis.hincrby key, "sum", value
      @redis.hincrby key, "count", 1
      @redis.hset key, "average", @redis.hget(key, "sum").to_i / @redis.hget(key, "count").to_f
    end

    @redis.hincrby "#{path_digest}::statuses", route.status, 1
  end
end
