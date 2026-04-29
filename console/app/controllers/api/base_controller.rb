module Api
  class BaseController < ApplicationController
    protect_from_forgery with: :exception

    private

    def valid_agent_id?
      params[:agent_id].to_s.match?(MetricSample::AGENT_ID_PATTERN)
    end
  end
end
