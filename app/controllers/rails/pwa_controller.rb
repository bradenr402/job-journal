class Rails::PwaController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection only: %i[manifest service_worker]

  def manifest
    respond_to do |format|
      format.json { render 'pwa/manifest', content_type: 'application/manifest+json' }
    end
  end

  def service_worker
    respond_to do |format|
      format.js { render 'pwa/service-worker', content_type: 'application/javascript' }
    end
  end
end
