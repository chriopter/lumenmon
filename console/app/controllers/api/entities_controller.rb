module Api
  class EntitiesController < BaseController
    def index
      samples_by_agent = MetricSample.order(:agent_id, :metric_name).group_by(&:agent_id)
      render json: samples_by_agent.map { |agent_id, samples| serialize_agent(agent_id, samples) }
    end

    private

    def serialize_agent(agent_id, samples)
      hostname = samples.find { |sample| sample.metric_name == "generic_hostname" }&.typed_value || agent_id
      {
        id: agent_id,
        agent_id: agent_id,
        hostname: hostname,
        display_name: hostname,
        status: status_for(samples),
        last_seen: samples.map(&:observed_at).max&.to_i,
        metrics: samples.map { |sample| serialize_metric(sample) }
      }
    end

    def serialize_metric(sample)
      {
        name: sample.metric_name,
        value: sample.typed_value,
        type: sample.data_type,
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
