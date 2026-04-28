module Api
  class CollectorsController < BaseController
    def coverage
      render json: {
        collectors: [],
        summary: {
          total_collectors: 0,
          metric_collectors: 0,
          metric_collectors_with_data: 0,
          metric_collectors_without_data: 0,
          event_only_collectors: 0,
          agents_seen: MetricSample.distinct.count(:agent_id)
        }
      }
    end
  end
end
