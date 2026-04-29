require "test_helper"

class MetricSampleHealthTest < ActiveSupport::TestCase
  test "stale metric is failed and stale" do
    sample = metric_sample(observed_at: 10.seconds.ago, interval: 1)

    assert sample.failed?
    assert_equal "stale", sample.health_status
    assert sample.health[:is_stale]
  end

  test "one time metric does not become stale" do
    sample = metric_sample(observed_at: 2.days.ago, interval: 0)

    assert_not sample.failed?
    assert_not sample.stale?
    assert_equal "online", sample.health_status
  end

  test "hard bounds breach is failed and critical" do
    sample = metric_sample(value: "101", max: 100)

    assert sample.failed?
    assert_equal "critical", sample.health_status
    assert sample.health[:out_of_bounds]
  end

  test "warning bounds breach is warning only" do
    sample = metric_sample(value: "91", max: 100, warn_max: 90)

    assert_not sample.failed?
    assert sample.warning?
    assert_equal "warning", sample.health_status
  end

  test "hard failure wins over warning" do
    sample = metric_sample(value: "101", max: 100, warn_max: 90)

    assert sample.failed?
    assert_not sample.warning?
    assert_equal "critical", sample.health_status
  end

  test "stale wins over old bounds breach" do
    sample = metric_sample(value: "101", max: 100, observed_at: 10.seconds.ago, interval: 1)

    assert sample.failed?
    assert sample.health[:out_of_bounds]
    assert_equal "stale", sample.health_status
  end

  test "host rollup cascades metric status" do
    heartbeat = metric_sample(metric_name: "generic_heartbeat", value: "1", data_type: "INTEGER")
    warning = metric_sample(metric_name: "generic_memory", value: "91", warn_max: 90)
    stale = metric_sample(metric_name: "generic_disk", observed_at: 10.seconds.ago, interval: 1)
    critical = metric_sample(metric_name: "generic_cpu", value: "101", max: 100)
    stale_heartbeat = metric_sample(metric_name: "generic_heartbeat", observed_at: 10.seconds.ago, interval: 1)

    assert_equal "degraded", MetricSample.rollup_status([heartbeat, warning])
    assert_equal "stale", MetricSample.rollup_status([heartbeat, stale])
    assert_equal "critical", MetricSample.rollup_status([heartbeat, warning, critical])
    assert_equal "offline", MetricSample.rollup_status([warning, critical])
    assert_equal "offline", MetricSample.rollup_status([stale_heartbeat, critical])
  end

  private

  def metric_sample(attributes = {})
    MetricSample.new({
      agent_id: "id_abc123",
      metric_name: "generic_cpu",
      value: "50",
      data_type: "REAL",
      interval: 60,
      observed_at: Time.current
    }.merge(attributes))
  end
end
