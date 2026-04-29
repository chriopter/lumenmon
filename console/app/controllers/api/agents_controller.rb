module Api
  class AgentsController < BaseController
    def tables
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      render json: {
        agent_id: params[:agent_id],
        tables: MetricSample.where(agent_id: params[:agent_id]).order(:metric_name).map { |sample| serialize_table(sample) }
      }
    end

    def email
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      render json: { email: "#{params[:agent_id]}@#{ENV.fetch("CONSOLE_HOST", "localhost")}" }
    end

    def name
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      profile = AgentProfile.ensure!(params[:agent_id])
      profile.update!(display_name: params[:name])

      render json: { success: true, agent_id: params[:agent_id], display_name: profile.display_name }
    rescue ActiveRecord::RecordInvalid => error
      Rails.logger.warn("agent name update failed for #{params[:agent_id]}: #{error.message}")
      render json: { success: false, error: "invalid display name" }, status: :bad_request
    end

    def reset
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      MetricSample.where(agent_id: params[:agent_id]).delete_all
      MetricObservation.where(agent_id: params[:agent_id]).delete_all
      PendingInvite.delete(params[:agent_id])
      render json: { success: true, status: "ok" }
    end

    def destroy
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      MetricSample.where(agent_id: params[:agent_id]).delete_all
      MetricObservation.where(agent_id: params[:agent_id]).delete_all
      AgentProfile.where(agent_id: params[:agent_id]).delete_all
      PendingInvite.delete(params[:agent_id])
      render json: { success: true }
    end

    def reorder
      render json: { success: true }
    end

    private

    def serialize_table(sample)
      timestamp = sample.observed_at.to_i
      value = sample.typed_value
      health = sample.health
      {
        metric_name: sample.metric_name,
        columns: {
          timestamp: timestamp,
          value: value,
          data_type: sample.data_type,
          interval: sample.interval,
          min: sample.min,
          max: sample.max,
          warn_min: sample.warn_min,
          warn_max: sample.warn_max
        },
        history: history_for(sample),
        staleness: {
          age: health[:age],
          is_stale: health[:is_stale],
          next_update_in: sample.interval.positive? ? [sample.observed_at.to_i + sample.interval - Time.current.to_i, 0].max : 0
        },
        health: health.except(:age)
      }
    end

    def numeric_history_value(value)
      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    def history_for(sample)
      observations = MetricObservation
        .where(agent_id: sample.agent_id, metric_name: sample.metric_name)
        .newest_first
        .limit(100)
        .to_a

      observations = [sample] if observations.empty?
      observations.reverse.filter_map do |observation|
        value = numeric_history_value(observation.typed_value)
        next unless value

        { timestamp: observation.observed_at.to_i, value: value }
      end
    end

  end
end
