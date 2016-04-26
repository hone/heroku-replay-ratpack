source "https://rubygems.org"

ruby "2.2.3",  engine: "jruby",  engine_version: "9.0.5.0"

gem "syslog-parser",  github: "hone/syslog-parser", branch: "jruby", require: "syslog/parser"
gem "syslog-stream"
gem "jbundler",       '0.9.2'
gem "ruby-kafka", require: "kafka"
gem "redis"
gem "concurrent-ruby", require: "concurrent"
gem "connection_pool"

group :test do
  gem "rspec"
end
