require_relative '../spec_helper'
require 'digest'
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
    let(:path)   { "/foo" }
    let(:digest) { Digest::SHA256.hexdigest(path) }
    let(:route) do
      Route.new(Generator.router(
        path:     path,
        connect:  5,
        service:  500
      ))
    end

    it "should insert metrics in redis" do
      metrics.insert(route)

      expect(redis.hkeys("routes")).to eq(["/foo"])
      expect(redis.hget("#{digest}::statuses", "200").to_i).to eq(1)

      name = "#{digest}::connect"
      expect(redis.hget(name, "count").to_i).to eq(1)
      expect(redis.hget(name, "sum").to_i).to eq(5)
      expect(redis.hget(name, "average").to_f).to eq(5.0)

      name = "#{digest}::service"
      expect(redis.hget(name, "count").to_i).to eq(1)
      expect(redis.hget(name, "sum").to_i).to eq(500)
      expect(redis.hget(name, "average").to_f).to eq(500.0)
    end
  end

  context "multiple messages" do
    let(:digest) do
      {
        "/foo" => Digest::SHA256.hexdigest("/foo"),
        "/bar" => Digest::SHA256.hexdigest("/bar")
      }
    end
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

      expect(redis.hkeys("routes").sort).to eq(["/bar", "/foo"])

      name = "#{digest["/foo"]}::statuses"
      expect(redis.hget(name, "200").to_i).to eq(2)

      name = "#{digest["/bar"]}::statuses"
      expect(redis.hget(name, "200").to_i).to eq(1)
      expect(redis.hget(name, "500").to_i).to eq(2)

      name = "#{digest["/foo"]}::connect"
      expect(redis.hget(name, "count").to_i).to eq(2)
      expect(redis.hget(name, "sum").to_i).to eq(12)
      expect(redis.hget(name, "average").to_f).to eq(6.0)

      name = "#{digest["/foo"]}::service"
      expect(redis.hget(name, "count").to_i).to eq(2)
      expect(redis.hget(name, "sum").to_i).to eq(500)
      expect(redis.hget(name, "average").to_f).to eq(250.0)
    end
  end
end
