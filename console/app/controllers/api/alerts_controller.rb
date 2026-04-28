module Api
  class AlertsController < BaseController
    def status
      render json: { configured: false, enabled: false, mode: "dry-run" }
    end
  end
end
