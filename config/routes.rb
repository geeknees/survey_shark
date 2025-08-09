Rails.application.routes.draw do
  # ActionCable endpoint for Turbo Streams over WebSocket
  mount ActionCable.server => "/cable"
  resources :projects do
    member do
      get :generate_invite_link
      post :generate_invite_link
    end

    resources :insights, only: [ :index, :show ]
  end
  resource :session
  resources :passwords, param: :token
  resources :admins, only: [] do
    member do
      get :edit_password
      patch :update_password
    end
  end

  # Public invite link route
  get "i/:token", to: "invites#show", as: :invite
  post "i/:token/start", to: "invites#start", as: :invite_start
  get "i/:token/attributes", to: "invites#attributes", as: :invite_attributes
  post "i/:token/create_participant", to: "invites#create_participant", as: :invite_create_participant

  # Conversations routes
  resources :conversations, only: [ :show ] do
    member do
      post :create_message
      post :skip
      get :messages
    end
  end

  # Thank you page routes
  resources :projects, only: [] do
    resource :thank_you, only: [ :show ] do
      post :restart
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "projects#index"
end
