class RouteMetrics
  def initialize(redis)
    @redis = redis
  end

  def insert(route)
    path = route.path

    @redis.sadd "routes", path

    [:service, :connect].each do |metric|
      value = route.send(metric).to_i
      key   = "#{path}::#{metric}"

      @redis.hincrby key, "sum", value
      @redis.hincrby key, "count", 1
      @redis.hset key, "average", @redis.hget(key, "sum").to_i / @redis.hget(key, "count").to_f
    end

    @redis.hincrby "#{path}::statuses", route.status, 1
  end
end
