require "open3"

module Api
  class InvitesController < BaseController
    def index
      render json: []
    end

    def create
      output, status = Open3.capture2e(Rails.root.join("core/enrollment/invite_create.sh").to_s)

      unless status.success?
        Rails.logger.error("invite_create failed: #{output}")
        return render json: { error: "invite creation failed" }, status: :internal_server_error
      end

      url = output.lines.find { |line| line.start_with?("lumenmon://") }&.strip
      render json: { url: url, invite_url: url }
    end
  end
end
