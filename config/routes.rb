Rails.application.routes.draw do
  # Defines the root path route ("/")
  root 'pages#home'

  resource :session, only: [ :new, :create, :destroy ]
  resource :registrations, only: [ :new, :create ]
  resources :passwords, only: [ :new, :create, :edit, :update ], param: :token

  resources :job_leads do
    member do
      patch :archive
      patch :unarchive
      patch :advance_status
      patch :revert_status
      patch :reject
      get :offer
      patch :set_offer
    end
  end

  resources :notes
  resources :interviews
  get 'search', to: 'search#index'
  get 'settings', to: 'settings#edit'
  patch 'settings', to: 'settings#update'
  patch 'reset_settings', to: 'settings#reset'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
