module Kafka::Producers
  class GenericProducer
    def self.logger
      @logger ||= Rails.logger.new(STDOUT)
    end

    def self.deliver(topic:, event:)
      # TODO: serilazer?
      payload = event.payload.to_json

      delivery_handle = KAFKA_PRODUCER.produce(
        topic: topic,
        payload: payload,
        key: event.aggregate_id.to_s
      )

      begin
        report = delivery_handle.wait(timeout: 5) # 5 seconds
        logger.info("Kafka message delivered to #{topic}, partition #{report.partition}, offset #{report.offset}")
      rescue Rdkafka::RdkafkaError => e
        logger.error("Kafka message delivery failed for topic '#{topic}', key '#{event.aggregate_id}': #{e.message}")
        # TODO realize repeat
        raise 
      end
    rescue StandardError => e
      logger.error("Failed to prepare or deliver Kafka message for topic '#{topic}', key '#{event.aggregate_id}': #{e.message}")
      raise 
    end
  end
end
