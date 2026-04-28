class DashboardController < ApplicationController
  def index
    @agents = MetricSample.order(:agent_id, :metric_name).group_by(&:agent_id)
  end
end
