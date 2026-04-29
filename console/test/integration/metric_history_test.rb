require "test_helper"

class MetricHistoryTest < ActionDispatch::IntegrationTest
  test "agent tables include observation history" do
    agent_id = "id_abc123"
    first_seen = 2.minutes.ago
    second_seen = 1.minute.ago

    MetricObservation.create!(
      agent_id: agent_id,
      metric_name: "generic_cpu",
      value: "12.5",
      data_type: "REAL",
      interval: 60,
      observed_at: first_seen
    )
    MetricObservation.create!(
      agent_id: agent_id,
      metric_name: "generic_cpu",
      value: "42.5",
      data_type: "REAL",
      interval: 60,
      observed_at: second_seen
    )
    MetricSample.create!(
      agent_id: agent_id,
      metric_name: "generic_cpu",
      value: "42.5",
      data_type: "REAL",
      interval: 60,
      observed_at: second_seen
    )

    get "/api/agents/#{agent_id}/tables"

    assert_response :success
    table = response.parsed_body.fetch("tables").first
    columns = table.fetch("columns")
    history = table.fetch("history")

    assert_equal "REAL", columns.fetch("data_type")
    assert_equal 42.5, columns.fetch("value")
    assert_equal %w[data_type interval max min timestamp value warn_max warn_min], columns.keys.sort
    assert_equal [12.5, 42.5], history.map { |point| point.fetch("value") }
  end

  test "entities api exposes canonical metric data type" do
    agent_id = "id_abc123"
    MetricSample.create!(
      agent_id: agent_id,
      metric_name: "generic_hostname",
      value: "devbox",
      data_type: "TEXT",
      interval: 60,
      observed_at: Time.current
    )

    get "/api/entities"

    assert_response :success
    metric = response.parsed_body.fetch("entities").first.fetch("metrics").first
    assert_equal "TEXT", metric.fetch("data_type")
    assert_not metric.key?("type")
  end

  test "agent reset clears latest values and history" do
    agent_id = "id_abc123"
    observed_at = Time.current

    MetricSample.create!(
      agent_id: agent_id,
      metric_name: "generic_memory",
      value: "64",
      data_type: "INTEGER",
      interval: 60,
      observed_at: observed_at
    )
    MetricObservation.create!(
      agent_id: agent_id,
      metric_name: "generic_memory",
      value: "64",
      data_type: "INTEGER",
      interval: 60,
      observed_at: observed_at
    )

    post "/api/agents/#{agent_id}/reset"

    assert_response :success
    assert_empty MetricSample.where(agent_id: agent_id)
    assert_empty MetricObservation.where(agent_id: agent_id)
  end

  test "observation retention purges values older than seven days" do
    agent_id = "id_abc123"
    MetricObservation.create!(
      agent_id: agent_id,
      metric_name: "generic_disk",
      value: "50",
      data_type: "REAL",
      interval: 60,
      observed_at: 8.days.ago
    )
    fresh = MetricObservation.create!(
      agent_id: agent_id,
      metric_name: "generic_disk",
      value: "51",
      data_type: "REAL",
      interval: 60,
      observed_at: 6.days.ago
    )

    MetricObservation.purge_expired!

    assert_equal [fresh], MetricObservation.where(agent_id: agent_id).to_a
  end
end
