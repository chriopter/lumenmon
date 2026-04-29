module Api
  class EntitiesController < BaseController
    def index
      samples_by_agent = MetricSample.order(:agent_id, :metric_name).group_by(&:agent_id)
      entities = samples_by_agent.map { |agent_id, samples| serialize_agent(agent_id, samples) }

      render json: {
        entities: entities,
        count: entities.count,
        timestamp: Time.current.to_i,
        source: "rails"
      }
    end

    private

    def serialize_agent(agent_id, samples)
      hostname = samples.find { |sample| sample.metric_name == "generic_hostname" }&.typed_value || agent_id
      {
        id: agent_id,
        type: "agent",
        valid: samples.any?,
        has_mqtt_user: mqtt_user?(agent_id),
        has_table: samples.any?,
        hostname: hostname,
        display_name: hostname,
        status: status_for(samples),
        last_seen: samples.map(&:observed_at).max&.to_i,
        cpu: samples.find { |sample| sample.metric_name == "generic_cpu" }&.typed_value,
        memory: samples.find { |sample| sample.metric_name == "generic_memory" }&.typed_value,
        disk: samples.find { |sample| sample.metric_name == "generic_disk" }&.typed_value,
        heartbeat: samples.find { |sample| sample.metric_name == "generic_heartbeat" }&.typed_value,
        total_collectors: samples.count,
        failed_collectors: failed_count(samples),
        warning_collectors: 0,
        pending_invite: PendingInvite.fetch(agent_id),
        metrics: samples.map { |sample| serialize_metric(sample) }
      }
    end

    def failed_count(samples)
      now = Time.current.to_i
      samples.count do |sample|
        sample.interval.positive? && now - sample.observed_at.to_i > sample.interval + 1
      end
    end

    def mqtt_user?(agent_id)
      data_dir = ENV.fetch("LUMENMON_DATA_DIR", "/data")
      passwd_file = Pathname(data_dir).join("mqtt", "passwd")
      return false unless passwd_file.exist?

      passwd_file.each_line.any? { |line| line.start_with?("#{agent_id}:") }
    end

    def serialize_metric(sample)
      {
        name: sample.metric_name,
        value: sample.typed_value,
        data_type: sample.data_type,
        interval: sample.interval,
        timestamp: sample.observed_at.to_i,
        min: sample.min,
        max: sample.max,
        warn_min: sample.warn_min,
        warn_max: sample.warn_max
      }.compact
    end

    def status_for(samples)
      latest = samples.map(&:observed_at).max
      return "offline" unless latest

      Time.current - latest > 120 ? "stale" : "online"
    end
  end
end
