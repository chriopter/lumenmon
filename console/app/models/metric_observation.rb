class MetricObservation < ApplicationRecord
  validates :agent_id, presence: true, format: { with: MetricSample::AGENT_ID_PATTERN }
  validates :metric_name, presence: true, format: { with: MetricSample::METRIC_NAME_PATTERN }
  validates :data_type, presence: true, inclusion: { in: %w[REAL INTEGER TEXT] }

  scope :newest_first, -> { order(observed_at: :desc) }

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
end
