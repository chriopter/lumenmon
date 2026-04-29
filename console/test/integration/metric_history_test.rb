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
    history = response.parsed_body.fetch("tables").first.fetch("history")
    assert_equal [12.5, 42.5], history.map { |point| point.fetch("value") }
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
end
