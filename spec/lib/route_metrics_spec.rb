require_relative '../spec_helper'
require 'redis'
require 'route_metrics'
require 'route'

RSpec.describe RouteMetrics do
  let(:redis)   { Redis.new(url: ENV['REDIS_URL']) }
  let(:metrics) { RouteMetrics.new(redis) }

  before do
    redis.flushall
  end

  context "a single message" do
    let(:route) do
      Route.new(Generator.router(
        path:     "/foo",
        connect:  5,
        service:  500
      ))
    end

    it "should insert metrics in redis" do
      metrics.insert(route)

      expect(redis.smembers("routes")).to eq(["/foo"])
      expect(redis.hget("/foo::statuses", "200").to_i).to eq(1)

      name = "/foo::connect"
      expect(redis.hget(name, "count").to_i).to eq(1)
      expect(redis.hget(name, "sum").to_i).to eq(5)
      expect(redis.hget(name, "average").to_f).to eq(5.0)

      name = "/foo::service"
      expect(redis.hget(name, "count").to_i).to eq(1)
      expect(redis.hget(name, "sum").to_i).to eq(500)
      expect(redis.hget(name, "average").to_f).to eq(500.0)
    end
  end

  context "multiple messages" do
    let(:routes) do
      [
        Route.new(Generator.router(
          path: "/foo",
          connect: 5,
          service: 300
        )),
        Route.new(Generator.router(
          path: "/foo",
          connect: 7,
          service: 200
        )),
        Route.new(Generator.router(
          path: "/bar",
          status: "200"
        )),
        Route.new(Generator.router(
          path: "/bar",
          status: "500"
        )),
        Route.new(Generator.router(
          path: "/bar",
          status: "500"
        ))
      ]
    end

    it "should insert metrics into redis" do
      routes.each {|route| metrics.insert(route) }

      expect(redis.smembers("routes").sort).to eq(["/bar", "/foo"])

      expect(redis.hget("/foo::statuses", "200").to_i).to eq(2)
      expect(redis.hget("/bar::statuses", "200").to_i).to eq(1)
      expect(redis.hget("/bar::statuses", "500").to_i).to eq(2)

      name = "/foo::connect"
      expect(redis.hget(name, "count").to_i).to eq(2)
      expect(redis.hget(name, "sum").to_i).to eq(12)
      expect(redis.hget(name, "average").to_f).to eq(6.0)

      name = "/foo::service"
      expect(redis.hget(name, "count").to_i).to eq(2)
      expect(redis.hget(name, "sum").to_i).to eq(500)
      expect(redis.hget(name, "average").to_f).to eq(250.0)
    end
  end
end
