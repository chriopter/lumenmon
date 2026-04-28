module Api
  class MessagesController < BaseController
    def index
      render json: { messages: [] }
    end

    def unread_counts
      render json: { counts: {} }
    end

    def staleness
      render json: { threshold_hours: 336, per_agent: [] }
    end

    def show
      render json: { error: "not found" }, status: :not_found
    end

    def destroy
      render json: { success: true }
    end

    def agent_messages
      render json: { messages: [] }
    end
  end
end
