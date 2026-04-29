#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"
require "json"
require "mqtt"

client = MQTT::Client.connect(
  host: ENV.fetch("MQTT_PLAIN_HOST", "127.0.0.1"),
  port: ENV.fetch("MQTT_PLAIN_PORT", "1883").to_i
)
client.subscribe("metrics/+/+")

puts "subscribed to metrics/+/+"

client.get do |topic, payload|
  _prefix, agent_id, metric_name = topic.split("/", 3)
  next unless agent_id&.match?(MetricSample::AGENT_ID_PATTERN)
  next unless metric_name&.match?(MetricSample::METRIC_NAME_PATTERN)

  data = JSON.parse(payload)
  sample = MetricSample.find_or_initialize_by(agent_id: agent_id, metric_name: metric_name)
  sample.value = data.fetch("value").to_s
  sample.data_type = data.fetch("type", "TEXT").to_s
  sample.interval = data.fetch("interval", 60).to_i
  sample.min = data["min"]
  sample.max = data["max"]
  sample.warn_min = data["warn_min"]
  sample.warn_max = data["warn_max"]
  sample.observed_at = Time.current
  sample.save!
rescue JSON::ParserError => e
  warn "invalid JSON on #{topic}: #{e.message}"
rescue ActiveRecord::RecordInvalid => e
  warn "invalid metric on #{topic}: #{e.message}"
rescue StandardError => e
  warn "failed to ingest #{topic}: #{e.class}: #{e.message}"
end
