module Api
  class BaseController < ApplicationController
    protect_from_forgery with: :null_session

    private

    def valid_agent_id?
      params[:agent_id].to_s.match?(MetricSample::AGENT_ID_PATTERN)
    end
  end
end
