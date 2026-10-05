Rails.application.routes.draw do
  # Defines the root path route ("/")
  root "pages#landing"
  get "dashboard", to: "pages#home", as: :dashboard

  resource :session, only: [ :new, :create, :destroy ]
  resource :registrations, only: [ :new, :create, :destroy ]
  resources :passwords, only: [ :new, :create, :edit, :update ], param: :token do
    get :sent, on: :collection
  end

  delete "sessions/others", to: "sessions#destroy_other_sessions", as: :destroy_other_sessions
  delete "sessions/inactive", to: "sessions#destroy_inactive_sessions", as: :destroy_inactive_sessions

  resources :job_leads do
    collection do
      post :autofill
    end

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

  get "search", to: "search#index"

  get "settings", to: "settings#edit"
  patch "settings", to: "settings#update"
  patch "reset_settings", to: "settings#reset"

  get "account", to: "users#account"
  get "account/edit", to: "users#edit", as: :edit_account
  patch "account/update", to: "users#update"
  get "account/export", to: "users#export", as: :account_export
  get "account/import", to: "imports#new", as: :new_account_import
  post "account/import", to: "imports#create", as: :account_imports
  get "account/import/:id/columns", to: "imports#columns", as: :columns_account_import
  get "account/import/:id/review", to: "imports#review", as: :review_account_import
  get "account/import/:id/summary", to: "imports#summary", as: :summary_account_import
  patch "account/import/:id", to: "imports#update", as: :account_import
  get "account/export/download(/:dataset)", to: "users#download_export", as: :download_account_export, constraints: { format: /json|csv/ }

  get "security", to: "pages#security"

  if Rails.env.development?
    get ":status_code", to: "errors#show",
      constraints: { status_code: /400|404|406|422|500/ }
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
