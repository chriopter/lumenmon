class AgentProfile < ApplicationRecord
  validates :agent_id, presence: true, uniqueness: true, format: { with: MetricSample::AGENT_ID_PATTERN }
  validates :display_name, length: { maximum: 80 }, allow_blank: true

  before_validation :normalize_display_name

  def self.ensure!(agent_id, display_name: nil, invited_at: nil)
    profile = find_or_initialize_by(agent_id: agent_id)
    profile.display_name = display_name if display_name.present? && profile.display_name.blank?
    profile.invited_at ||= invited_at
    profile.save!
    profile
  end

  def visible_name(metric_hostname = nil)
    display_name.presence || metric_hostname.presence || agent_id
  end

  private

  def normalize_display_name
    self.display_name = display_name.to_s.strip.presence
  end
end
