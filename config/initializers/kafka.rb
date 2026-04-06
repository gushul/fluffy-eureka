KAFKA_PRODUCER_CONFIG = {
  "bootstrap.servers": ENV.fetch("KAFKA_BROKERS") { "localhost:9092" },
  "enable.idempotence": true,
  "acks": "all",
  "retries": 5,
  "max.in.flight.requests.per.connection": 5
}

KAFKA_PRODUCER = Rdkafka::Config.new(KAFKA_PRODUCER_CONFIG).producer

at_exit do
  puts "Flushing Kafka producer..."
  KAFKA_PRODUCER&.flush
  puts "Kafka producer flushed."
end

