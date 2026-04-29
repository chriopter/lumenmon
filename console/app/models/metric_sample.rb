class MetricSample < ApplicationRecord
  AGENT_ID_PATTERN = /\Aid_[0-9a-f]+\z/
  METRIC_NAME_PATTERN = /\A[a-zA-Z0-9_.:-]+\z/
  STALE_GRACE_SECONDS = 1

  validates :agent_id, presence: true, format: { with: AGENT_ID_PATTERN }
  validates :metric_name, presence: true, format: { with: METRIC_NAME_PATTERN }
  validates :data_type, presence: true, inclusion: { in: %w[REAL INTEGER TEXT] }

  scope :fresh_first, -> { order(observed_at: :desc) }

  def self.rollup_status(samples, now = Time.current)
    heartbeat = samples.find { |sample| sample.metric_name == "generic_heartbeat" }
    return "offline" if heartbeat.nil? || heartbeat.stale?(now)
    return "critical" if samples.any? { |sample| sample.critical?(now) }
    return "stale" if samples.any? { |sample| sample.stale?(now) }
    return "degraded" if samples.any? { |sample| sample.warning?(now) }

    "online"
  end

  def self.failed_count(samples, now = Time.current)
    samples.count { |sample| sample.failed?(now) }
  end

  def self.warning_count(samples, now = Time.current)
    samples.count { |sample| sample.warning?(now) }
  end

  def typed_value
    case data_type
    when "REAL"
      value.to_f
    when "INTEGER"
      value.to_i
    else
      value
    end
  end

  def health(now = Time.current)
    age = [now - observed_at, 0].max
    stale = interval.to_i.positive? && age > interval.to_i + STALE_GRACE_SECONDS
    number = numeric_value
    out_of_bounds = false
    warning_out_of_bounds = false
    bounds_error = nil

    if number
      if !min.nil? && number < min
        out_of_bounds = true
        bounds_error = "value #{number} < min #{min}"
      elsif !max.nil? && number > max
        out_of_bounds = true
        bounds_error = "value #{number} > max #{max}"
      end

      warning_out_of_bounds = (!warn_min.nil? && number < warn_min) || (!warn_max.nil? && number > warn_max)
    end

    status = if stale
      "stale"
    elsif out_of_bounds
      "critical"
    elsif warning_out_of_bounds
      "warning"
    else
      "online"
    end

    {
      age: age.to_i,
      is_failed: stale || out_of_bounds,
      is_critical: out_of_bounds,
      is_warning: status == "warning",
      is_stale: stale,
      out_of_bounds: out_of_bounds,
      warning_out_of_bounds: warning_out_of_bounds,
      bounds_error: bounds_error,
      status: status
    }
  end

  def health_status(now = Time.current)
    health(now)[:status]
  end

  def critical?(now = Time.current)
    health_status(now) == "critical"
  end

  def stale?(now = Time.current)
    health(now)[:is_stale]
  end

  def failed?(now = Time.current)
    health(now)[:is_failed]
  end

  def warning?(now = Time.current)
    health(now)[:is_warning]
  end

  def numeric_value
    return nil unless %w[REAL INTEGER].include?(data_type)

    Float(typed_value)
  rescue ArgumentError, TypeError
    nil
  end
end
