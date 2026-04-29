require "test_helper"

class DashboardFragmentsTest < ActionDispatch::IntegrationTest
  test "direct hosts fragment redirects to full dashboard" do
    get "/hosts"

    assert_redirected_to root_path
  end

  test "turbo hosts fragment still renders partial" do
    get "/hosts", headers: { "Turbo-Frame" => "hosts" }

    assert_response :success
    assert_includes response.body, "<turbo-frame"
  end

  test "direct agent metrics fragment redirects to full dashboard" do
    AgentProfile.create!(agent_id: "id_abc123")

    get "/agents/id_abc123/metrics"

    assert_redirected_to "#{root_path}#agent=id_abc123"
  end
end
