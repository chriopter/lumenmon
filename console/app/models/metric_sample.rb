class MetricSample < ApplicationRecord
  AGENT_ID_PATTERN = /\Aid_[0-9a-f]+\z/
  METRIC_NAME_PATTERN = /\A[a-zA-Z0-9_.:-]+\z/

  validates :agent_id, presence: true, format: { with: AGENT_ID_PATTERN }
  validates :metric_name, presence: true, format: { with: METRIC_NAME_PATTERN }
  validates :data_type, presence: true, inclusion: { in: %w[REAL INTEGER TEXT] }

  scope :fresh_first, -> { order(observed_at: :desc) }

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
