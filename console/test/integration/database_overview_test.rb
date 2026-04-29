require "test_helper"

class DatabaseOverviewTest < ActionDispatch::IntegrationTest
  test "shows database tables and rows" do
    MetricSample.create!(
      agent_id: "id_abc123",
      metric_name: "generic_cpu",
      value: "42.1",
      data_type: "REAL",
      interval: 60,
      observed_at: Time.current
    )

    get "/database"

    assert_response :success
    assert_select ".database-table-link", text: /metric_samples/
    assert_select ".database-data-table td", text: /generic_cpu/
  end

  test "ignores invalid table parameter" do
    get "/database", params: { table: "metric_samples;DROP TABLE metric_samples" }

    assert_response :success
    assert_select ".database-header h2", text: "metric_samples"
  end
end
