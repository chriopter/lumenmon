module Api
  class EntitiesController < BaseController
    def index
      samples_by_agent = MetricSample.order(:agent_id, :metric_name).group_by(&:agent_id)
      profiles_by_agent = AgentProfile.all.index_by(&:agent_id)
      agent_ids = samples_by_agent.keys | profiles_by_agent.keys
      entities = agent_ids.sort.map { |agent_id| serialize_agent(agent_id, samples_by_agent.fetch(agent_id, []), profiles_by_agent[agent_id]) }

      render json: {
        entities: entities,
        count: entities.count,
        timestamp: Time.current.to_i,
        source: "rails"
      }
    end

    private

    def serialize_agent(agent_id, samples, profile = nil)
      original_hostname = samples.find { |sample| sample.metric_name == "generic_hostname" }&.typed_value
      hostname = (profile || AgentProfile.new(agent_id: agent_id)).visible_name(original_hostname)
      status = status_for(samples)
      mail_only = samples.empty?
      {
        id: agent_id,
        type: "agent",
        valid: true,
        has_mqtt_user: mqtt_user?(agent_id),
        has_table: samples.any?,
        hostname: hostname,
        original_hostname: original_hostname,
        display_name: hostname,
        status: status,
        last_seen: samples.map(&:observed_at).max&.to_i,
        cpu: samples.find { |sample| sample.metric_name == "generic_cpu" }&.typed_value,
        memory: samples.find { |sample| sample.metric_name == "generic_memory" }&.typed_value,
        disk: samples.find { |sample| sample.metric_name == "generic_disk" }&.typed_value,
        heartbeat: samples.find { |sample| sample.metric_name == "generic_heartbeat" }&.typed_value,
        total_collectors: samples.count,
        failed_collectors: failed_count(samples),
        warning_collectors: warning_count(samples),
        mail_only: mail_only,
        is_mail_only: mail_only,
        pending_invite: PendingInvite.fetch(agent_id),
        metrics: samples.map { |sample| serialize_metric(sample) }
      }
    end

    def failed_count(samples)
      MetricSample.failed_count(samples)
    end

    def warning_count(samples)
      MetricSample.warning_count(samples)
    end

    def mqtt_user?(agent_id)
      data_dir = ENV.fetch("LUMENMON_DATA_DIR", "/data")
      passwd_file = Pathname(data_dir).join("mqtt", "passwd")
      return false unless passwd_file.exist?

      passwd_file.each_line.any? { |line| line.start_with?("#{agent_id}:") }
    end

    def serialize_metric(sample)
      health = sample.health
      {
        name: sample.metric_name,
        value: sample.typed_value,
        data_type: sample.data_type,
        interval: sample.interval,
        timestamp: sample.observed_at.to_i,
        min: sample.min,
        max: sample.max,
        warn_min: sample.warn_min,
        warn_max: sample.warn_max,
        health: health
      }.compact
    end

    def status_for(samples)
      return "mail-only" if samples.empty?

      MetricSample.rollup_status(samples)
    end
  end
end
