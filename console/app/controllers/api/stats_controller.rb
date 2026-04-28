module Api
  class StatsController < BaseController
    def show
      render json: {
        agents: MetricSample.distinct.count(:agent_id),
        metrics: MetricSample.count,
        runtime: "rails"
      }
    end
  end
end
