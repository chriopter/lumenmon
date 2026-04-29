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
    return redirect_to(root_path(anchor: "agent=#{params[:agent_id]}")) unless turbo_frame_request?

    samples = MetricSample.where(agent_id: params[:agent_id]).order(:metric_name).to_a
    profile = AgentProfile.find_by(agent_id: params[:agent_id])
    return head :not_found if samples.empty? && profile.nil?

    @agent = build_agent(params[:agent_id], samples, profile)
    part = params[:part] == "bottom" ? "bottom" : "top"
    render partial: "dashboard/agent_metrics_#{part}_frame", locals: { agent: @agent }
  end

  def hosts
    return redirect_to(root_path) unless turbo_frame_request?

    render partial: "dashboard/hosts_frame", locals: { agents: load_agents }
  end

  private

  def load_agents
    unread_counts = Message.unread.group(:agent_id).count
    samples_by_agent = MetricSample.order(:agent_id, :metric_name).group_by(&:agent_id)
    profiles_by_agent = AgentProfile.all.index_by(&:agent_id)
    agent_ids = (samples_by_agent.keys | profiles_by_agent.keys).sort

    agent_ids.map do |agent_id|
      build_agent(agent_id, samples_by_agent.fetch(agent_id, []), profiles_by_agent[agent_id])
        .merge(unread_mail: unread_counts[agent_id].to_i)
    end.sort_by { |agent| [agent[:status] == "online" ? 0 : 1, agent[:hostname].to_s] }
  end

  def build_agent(agent_id, samples, profile = nil)
    metric_map = samples.index_by(&:metric_name)
    original_hostname = metric_map["generic_hostname"]&.typed_value
    {
      id: agent_id,
      hostname: (profile || AgentProfile.new(agent_id: agent_id)).visible_name(original_hostname),
      original_hostname: original_hostname,
      display_name: profile&.display_name,
      status: status_for(samples),
      samples: samples,
      metrics: metric_map,
      last_seen: samples.map(&:observed_at).max
    }
  end

  def status_for(samples)
    return "mail-only" if samples.empty?

    MetricSample.rollup_status(samples)
  end
end
