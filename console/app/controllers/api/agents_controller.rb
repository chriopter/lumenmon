module Api
  class AgentsController < BaseController
    def tables
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      render json: {
        agent_id: params[:agent_id],
        tables: MetricSample.where(agent_id: params[:agent_id]).order(:metric_name).pluck(:metric_name)
      }
    end

    def reset
      return render(json: { error: "invalid agent_id" }, status: :bad_request) unless valid_agent_id?

      MetricSample.where(agent_id: params[:agent_id]).delete_all
      render json: { status: "ok" }
    end
  end
end
