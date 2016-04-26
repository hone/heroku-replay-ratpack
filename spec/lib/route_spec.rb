require_relative '../spec_helper'
require 'route'

RSpec.describe Route do
  let(:input) { Generator.router(path: "/foo") }

  it "should parse a route properly" do
    route = Route.new(input)
    expect(route.path).to eq("/foo")
  end
end
