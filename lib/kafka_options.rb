module KafkaOptions
  class << self
    def ssl
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

    def default
      {
        seed_brokers: ENV['KAFKA_URL']
      }.merge(ssl)
    end
  end
end
