require "open3"
require "json"

module Api
  class InvitesController < BaseController
    def index
      render json: {
        invites: PendingInvite.all.values.map { |invite| invite.slice(:username, :fingerprint, :email_address) },
        count: PendingInvite.all.count
      }
    end

    def create
      output, status = Open3.capture2e({ "CONSOLE_HOST" => console_host, "LUMENMON_SKIP_PROFILE" => "1" }, invite_script.to_s)

      unless status.success?
        Rails.logger.error("invite_create failed: #{output}")
        return render json: { success: false, error: "invite creation failed" }, status: :internal_server_error
      end

      invite_data = read_invite_data(output)
      unless invite_data
        Rails.logger.error("invite_create produced no invite data: #{output}")
        return render json: { success: false, error: "invite data missing" }, status: :internal_server_error
      end

      username = invite_data.fetch("username")
      invite_url = invite_data.fetch("url")
      install_command = "curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/install.sh | bash -s '#{invite_url}'"
      email_address = "#{username}@#{console_host}"

      payload = {
        username: username,
        invite_url: invite_url,
        install_command: install_command,
        fingerprint: invite_data["fingerprint"],
        email_address: email_address
      }
      PendingInvite.store(username, payload)
      AgentProfile.ensure!(username, invited_at: Time.current)

      render json: payload.merge(success: true, message: "Invite created. Copy it now; the password is only returned once.")
    end

    private

    def invite_script
      Rails.root.join("core/enrollment/invite_create.sh")
    end

    def console_host
      ENV.fetch("CONSOLE_HOST", "localhost")
    end

    def read_invite_data(output)
      json_file = Pathname("/tmp/last_invite.json")
      if json_file.exist?
        JSON.parse(json_file.read)
      else
        invite_url = output.lines.find { |line| line.start_with?("lumenmon://") }&.strip
        return nil unless invite_url

        username = invite_url.delete_prefix("lumenmon://").split(":", 2).first
        fingerprint = invite_url.split("#", 2).last
        { "username" => username, "url" => invite_url, "fingerprint" => fingerprint }
      end
    ensure
      json_file&.delete if json_file&.exist?
    end
  end
end
