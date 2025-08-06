class Rails::PwaController < ApplicationController
  def manifest
    respond_to do |format|
      format.json { render 'pwa/manifest', content_type: 'application/manifest+json' }
    end
  end

  def service_worker
    respond_to do |format|
      format.js { render 'pwa/service_worker', content_type: 'application/javascript' }
    end
  end
end
