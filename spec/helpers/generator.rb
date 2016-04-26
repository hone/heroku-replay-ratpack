module Generator
  class << self
    def router(path: "/foo/bar", connect: 500, service: 10, wait: 1, status: 200)
      {
        "prival"          => 158,
        "version"         => 1,
        "timestamp"       => "2016-04-21 21:56:01 +0000",
        "hostname"        => "host",
        "app_name"        => "heroku",
        "procid"          => "router",
        "msgid"           => nil,
        "structured_data" => nil,
        "msg"             => "at=info method=GET path=\"#{path}\" host=www.codetriage.com request_id=e1d26e69-adde-4ef0-9c33-32704e2a2da3 fwd=\"151.80.31.164\" dyno=web.3 connect=#{connect}ms service=#{service}ms status=#{status} bytes=42209\n"
      }
    end
  end
end
