class ApplicationController < ActionController::Base
  protect_from_forgery

  helper_method :current_user
  private
  def current_user
  	@current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  #filter out password parameters from log files
  #filter_parameter_logging :password
end
