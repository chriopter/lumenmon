module Api
  class VersionController < BaseController
    def latest
      render json: { version: "", source: "not_configured" }
    end
  end
end
