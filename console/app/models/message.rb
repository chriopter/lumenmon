require "mail"

class Message < ApplicationRecord
  validates :agent_id, presence: true, format: { with: MetricSample::AGENT_ID_PATTERN }
  validates :mail_from, :mail_to, :subject, presence: true
  validates :received_at, presence: true

  scope :newest_first, -> { order(received_at: :desc) }
  scope :unread, -> { where(read: false) }

  def self.ingest_mqtt!(agent_id, data)
    create!(
      agent_id: agent_id,
      mail_from: data["mail_from"].presence || "unknown",
      mail_to: data["mail_to"].presence || "#{agent_id}@#{ENV.fetch("CONSOLE_HOST", "localhost")}",
      subject: data["subject"].presence || "(no subject)",
      body: data["body"].to_s,
      raw_content: data["raw_content"].presence || data["raw"].presence || data["body"].to_s,
      received_at: Time.current
    )
  end

  def self.ingest_smtp!(mail_from:, recipients:, raw_content:)
    agent_id = agent_id_for_recipients(recipients)
    return nil unless agent_id

    parsed = Mail.read_from_string(raw_content)
    body = extract_body(parsed)

    create!(
      agent_id: agent_id,
      mail_from: parsed.from&.first.presence || mail_from.presence || "unknown",
      mail_to: recipients.join(", "),
      subject: parsed.subject.presence || "(no subject)",
      body: body,
      raw_content: raw_content,
      received_at: Time.current
    )
  end

  def self.agent_id_for_recipients(recipients)
    recipients.filter_map { |recipient| agent_id_for_recipient(recipient) }.first
  end

  def self.agent_id_for_recipient(recipient)
    local_part = recipient.to_s[/<?([^<>\s@]+)@/, 1]&.downcase
    return nil unless local_part

    known_agent_ids.find { |agent_id| agent_id == local_part || agent_id.delete_prefix("id_") == local_part }
  end

  def self.known_agent_ids
    ids = MetricSample.distinct.pluck(:agent_id) | distinct.pluck(:agent_id)
    passwd_file = Pathname(ENV.fetch("LUMENMON_DATA_DIR", "/data")).join("mqtt", "passwd")

    if passwd_file.exist?
      passwd_file.each_line do |line|
        username = line.split(":", 2).first.to_s.strip
        ids << username if username.match?(MetricSample::AGENT_ID_PATTERN)
      end
    end

    ids.uniq
  end

  def self.extract_body(mail)
    if mail.multipart?
      part = mail.text_part || mail.parts.find { |candidate| candidate.mime_type == "text/plain" }
      return part.body.decoded.to_s if part
    end

    mail.body.decoded.to_s
  rescue StandardError
    ""
  end
end
