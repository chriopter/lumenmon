class DashboardController < ApplicationController
  def index
    @agents = load_agents
    @selected_agent = @agents.first
    @pending_invites = PendingInvite.all
    @stats = {
      agents: @agents.count,
      metrics: MetricSample.count,
      online: @agents.count { |agent| agent[:status] == "online" },
      pending_invites: @pending_invites.count
    }
  end

  def agent_metrics
    samples = MetricSample.where(agent_id: params[:agent_id]).order(:metric_name).to_a
    return head :not_found if samples.empty?

    @agent = build_agent(params[:agent_id], samples)
    render partial: "dashboard/agent_metrics_frame", locals: { agent: @agent }
  end

  def hosts
    render partial: "dashboard/hosts_frame", locals: { agents: load_agents }
  end

  private

  def load_agents
    unread_counts = Message.unread.group(:agent_id).count
    MetricSample.order(:agent_id, :metric_name).group_by(&:agent_id).map do |agent_id, samples|
      build_agent(agent_id, samples).merge(unread_mail: unread_counts[agent_id].to_i)
    end.sort_by { |agent| [agent[:status] == "online" ? 0 : 1, agent[:hostname].to_s] }
  end

  def build_agent(agent_id, samples)
    metric_map = samples.index_by(&:metric_name)
    {
      id: agent_id,
      hostname: metric_map["generic_hostname"]&.typed_value || agent_id,
      status: status_for(samples),
      samples: samples,
      metrics: metric_map,
      last_seen: samples.map(&:observed_at).max
    }
  end

  def status_for(samples)
    latest = samples.map(&:observed_at).max
    return "offline" unless latest

    Time.current - latest > 20 ? "stale" : "online"
  end
end
