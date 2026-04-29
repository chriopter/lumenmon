Rails.application.routes.draw do
  root "dashboard#index"

  get "agents/:agent_id/metrics" => "dashboard#agent_metrics", as: :agent_metrics
  get "database" => "database#index"
  get "health" => "health#show"
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "entities" => "entities#index"
    get "stats" => "stats#show"
    get "version/latest" => "version#latest"
    get "collectors/coverage" => "collectors#coverage"
    get "messages" => "messages#index"
    get "messages/unread-counts" => "messages#unread_counts"
    get "messages/staleness" => "messages#staleness"
    get "messages/:message_id" => "messages#show"
    delete "messages/:message_id" => "messages#destroy"
    get "alerts/status" => "alerts#status"
    get "invites" => "invites#index"
    post "invites/create" => "invites#create"
    post "invites/create/full" => "invites#create"
    get "agents/:agent_id/tables" => "agents#tables"
    get "agents/:agent_id/email" => "agents#email"
    put "agents/:agent_id/name" => "agents#name"
    delete "agents/:agent_id" => "agents#destroy"
    put "agents/reorder" => "agents#reorder"
    post "agents/:agent_id/reset" => "agents#reset"
    get "agents/:agent_id/messages" => "messages#agent_messages"
  end
end
