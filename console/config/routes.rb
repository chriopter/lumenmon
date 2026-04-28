Rails.application.routes.draw do
  root "dashboard#index"

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
    get "alerts/status" => "alerts#status"
    get "invites" => "invites#index"
    post "invites/create" => "invites#create"
    post "invites/create/full" => "invites#create"
    get "agents/:agent_id/tables" => "agents#tables"
    post "agents/:agent_id/reset" => "agents#reset"
  end
end
