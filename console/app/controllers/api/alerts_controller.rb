module Api
  class AlertsController < BaseController
    def status
      render json: { status: "ok", alerts: [] }
    end
  end
end
