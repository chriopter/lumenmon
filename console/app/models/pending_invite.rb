class PendingInvite
  @invites = {}

  class << self
    def all
      @invites
    end

    def store(agent_id, data)
      @invites[agent_id] = data
    end

    def fetch(agent_id)
      @invites[agent_id]
    end

    def delete(agent_id)
      @invites.delete(agent_id)
    end
  end
end
