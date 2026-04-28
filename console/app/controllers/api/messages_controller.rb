module Api
  class MessagesController < BaseController
    def index
      render json: []
    end

    def unread_counts
      render json: {}
    end

    def staleness
      render json: { stale_after_hours: 336, status: "warning_only" }
    end
  end
end
