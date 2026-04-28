class HealthController < ApplicationController
  def show
    render json: {
      status: "ok",
      app: "lumenmon-console",
      runtime: "rails",
      timestamp: Time.now.to_i
    }
  end
end
