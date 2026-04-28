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

      render json: { success: true, agent_id: params[:agent_id], display_name: params[:name].presence }
    end

    def reset
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      MetricSample.where(agent_id: params[:agent_id]).delete_all
      PendingInvite.delete(params[:agent_id])
      render json: { success: true, status: "ok" }
    end

    def destroy
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      MetricSample.where(agent_id: params[:agent_id]).delete_all
      PendingInvite.delete(params[:agent_id])
      render json: { success: true }
    end

    def reorder
      render json: { success: true }
    end

    private

    def serialize_table(sample)
      timestamp = sample.observed_at.to_i
      age = [Time.current.to_i - timestamp, 0].max
      value = sample.typed_value
      {
        metric_name: sample.metric_name,
        columns: {
          timestamp: timestamp,
          value: value,
          value_real: sample.data_type == "REAL" ? value : nil,
          value_int: sample.data_type == "INTEGER" ? value : nil,
          value_text: sample.data_type == "TEXT" ? value : nil,
          interval: sample.interval,
          min_value: sample.min,
          max_value: sample.max,
          warn_min_value: sample.warn_min,
          warn_max_value: sample.warn_max
        },
        history: [{ timestamp: timestamp, value: numeric_history_value(value) }].compact,
        staleness: {
          age: age,
          is_stale: sample.interval.positive? && age > sample.interval + 1,
          next_update_in: sample.interval.positive? ? [sample.interval - age, 0].max : 0
        },
        health: health_for(sample, value, age)
      }
    end

    def numeric_history_value(value)
      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    def health_for(sample, value, age)
      number = numeric_history_value(value)
      stale = sample.interval.positive? && age > sample.interval + 1
      out_of_bounds = false
      warning_out_of_bounds = false

      if number
        out_of_bounds = (!sample.min.nil? && number < sample.min) || (!sample.max.nil? && number > sample.max)
        warning_out_of_bounds = (!sample.warn_min.nil? && number < sample.warn_min) || (!sample.warn_max.nil? && number > sample.warn_max)
      end

      {
        is_failed: stale || out_of_bounds,
        is_warning: warning_out_of_bounds,
        is_stale: stale,
        out_of_bounds: out_of_bounds,
        warning_out_of_bounds: warning_out_of_bounds
      }
    end
  end
end
