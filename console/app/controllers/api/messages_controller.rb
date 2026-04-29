module Api
  class MessagesController < BaseController
    DEFAULT_LIMIT = 50
    MAX_LIMIT = 500
    DEFAULT_STALENESS_HOURS = 336
    MAX_STALENESS_HOURS = 8_760

    def index
      messages = Message.newest_first
      messages = messages.where(agent_id: params[:agent_id]) if params[:agent_id].present?
      messages = messages.unread if params[:unread].to_s == "true"

      render json: { messages: messages.limit(limit_param(DEFAULT_LIMIT)).map { |message| serialize_summary(message) } }
    end

    def unread_counts
      render json: { counts: Message.unread.group(:agent_id).count }
    end

    def staleness
      threshold_hours = hours_param(DEFAULT_STALENESS_HOURS)
      now = Time.current
      per_agent = Message.group(:agent_id).maximum(:received_at).map do |agent_id, last_received|
        age_hours = ((now - last_received) / 1.hour).floor
        {
          agent_id: agent_id,
          last_received: last_received.iso8601,
          age_hours: age_hours,
          is_stale: age_hours > threshold_hours
        }
      end
      global_last = per_agent.filter_map { |entry| entry[:last_received] }.max
      global_age = global_last ? ((now - Time.iso8601(global_last)) / 1.hour).floor : nil

      render json: {
        threshold_hours: threshold_hours,
        global: {
          last_received: global_last,
          age_hours: global_age,
          is_stale: global_age.nil? || global_age > threshold_hours
        },
        summary: {
          agents_with_mail: per_agent.count,
          stale_agents: per_agent.count { |entry| entry[:is_stale] }
        },
        per_agent: per_agent
      }
    end

    def show
      message = Message.find_by(id: params[:message_id])
      return render(json: { error: "not found" }, status: :not_found) unless message

      message.update!(read: true)
      render json: serialize_detail(message)
    end

    def destroy
      message = Message.find_by(id: params[:message_id])
      return render(json: { error: "not found" }, status: :not_found) unless message

      message.destroy!
      render json: { success: true }
    end

    def agent_messages
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless params[:agent_id].match?(MetricSample::AGENT_ID_PATTERN)

      messages = Message.where(agent_id: params[:agent_id]).newest_first.limit(limit_param(DEFAULT_LIMIT))
      render json: { messages: messages.map { |message| serialize_summary(message) } }
    end

    private

    def limit_param(default)
      value = params[:limit].presence || default
      limit = Integer(value)
      raise ArgumentError if limit < 1

      [limit, MAX_LIMIT].min
    rescue ArgumentError, TypeError
      default
    end

    def hours_param(default)
      value = params[:hours].presence || default
      hours = Integer(value)
      raise ArgumentError if hours < 1

      [hours, MAX_STALENESS_HOURS].min
    rescue ArgumentError, TypeError
      default
    end

    def serialize_summary(message)
      {
        id: message.id,
        agent_id: message.agent_id,
        mail_from: message.mail_from,
        mail_to: message.mail_to,
        subject: message.subject,
        received_at: message.received_at.iso8601,
        read: message.read
      }
    end

    def serialize_detail(message)
      serialize_summary(message).merge(body: message.body.to_s)
    end
  end
end
