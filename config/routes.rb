Rails.application.routes.draw do
  # Defines the root path route ("/")
  root 'pages#home'

  resource :session, only: [ :new, :create, :destroy ]
  resource :registrations, only: [ :new, :create, :destroy ]
  resources :passwords, only: [ :new, :create, :edit, :update ], param: :token

  delete 'sessions/others', to: 'sessions#destroy_other_sessions', as: :destroy_other_sessions

  resources :job_leads do
    member do
      patch :archive
      patch :unarchive
      patch :advance_status
      patch :revert_status
      patch :reject
      get :offer
      patch :set_offer
      get :history
      patch :update_history
    end
  end

  resources :notes

  resources :interviews do
    member do
      get :add_to_calendar
    end
  end

  resources :tags, only: [ :index, :edit, :update, :destroy ]

  get 'search', to: 'search#index'

  get 'settings', to: 'settings#edit'
  patch 'settings', to: 'settings#update'
  patch 'reset_settings', to: 'settings#reset'

  get 'account', to: 'users#account'
  get 'account/edit', to: 'users#edit', as: :edit_account
  patch 'account/update', to: 'users#update'

  get 'security', to: 'pages#security'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
end
