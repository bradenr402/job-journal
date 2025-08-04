class ErrorsController < ApplicationController
  allow_unauthenticated_access only: :show
  layout 'error'

  def show
    @exception = request.env['action_dispatch.exception']
    @status_code =
      params[:status_code]&.to_i ||
      status_code_from_exception(@exception) ||
      ActionDispatch::ExceptionWrapper.new(request.env, @exception).status_code rescue 500

    Rails.logger.error("Error #{@status_code}: #{@exception.message}") if @status_code.to_i == 500

    render view_for_code(@status_code)
  end

  private

  def status_code_from_exception(exception)
    case exception
    when ActionController::RoutingError, ActiveRecord::RecordNotFound
      404
    else
      nil
    end
  end

  def view_for_code(code)
    code.to_s.in?(%w[ 404 500 ]) ? code.to_s : '404'
  end
end
