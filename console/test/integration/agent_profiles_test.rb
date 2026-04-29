require "test_helper"

class AgentProfilesTest < ActionDispatch::IntegrationTest
  test "invite creation creates visible host profile before metrics arrive" do
    status = Object.new
    def status.success? = true

    output = "lumenmon://id_abc123:secret@console.example.test:8884#AA:BB\n"
    Pathname("/tmp/last_invite.json").delete if Pathname("/tmp/last_invite.json").exist?
    original_capture = Open3.method(:capture2e)

    Open3.define_singleton_method(:capture2e) { |_env, _script| [output, status] }
    post "/api/invites/create/full"

    assert_response :success
    assert AgentProfile.exists?(agent_id: "id_abc123")

    get "/"
    assert_response :success
    assert_select "#agent-row-id_abc123"
    assert_select ".health-badge.mail-only", text: "mail-only"
  ensure
    Open3.define_singleton_method(:capture2e) { |*args, **kwargs, &block| original_capture.call(*args, **kwargs, &block) } if original_capture
    Pathname("/tmp/last_invite.json").delete if Pathname("/tmp/last_invite.json").exist?
  end

  test "agent display name can be changed" do
    AgentProfile.create!(agent_id: "id_abc123")

    put "/api/agents/id_abc123/name", params: { name: "backup nas" }, as: :json

    assert_response :success
    assert_equal "backup nas", AgentProfile.find_by!(agent_id: "id_abc123").display_name

    get "/"
    assert_response :success
    assert_select "#agent-row-id_abc123 strong", text: "backup nas"
  end
end
