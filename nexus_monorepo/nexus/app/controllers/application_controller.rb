class ApplicationController < ActionController::Base
  include LtiHelper
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception
  protect_from_forgery with: :null_session
  # Devise strong parameters
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :lti_auth
  skip_before_action :verify_authenticity_token, if: :lti_request?
  rescue_from LtiLaunch::Unauthorized, with: :handle_lti_error
  rescue_from LtiRegistration::Error, with: :handle_lti_reg_error

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) do |u|
      u.permit(:email, :first_name, :last_name, :student_id, :password, :password_confirmation)
    end
    # Use the below instead for devise versions > 4.1
    # devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :first_name, :last_name, :student_id, :password, :password_confirmation])
  end

  def devise_current_user
    @devise_current_user ||= warden.authenticate(scope: :user)
  end

  def current_user
    unless LtiUtils.invalid_token(params)
      return nil if @is_teacher && !LtiUtils.get_user_id(params)
      lti_session = LtiSession.where({ lti_tool: LtiUtils.get_tool_id(params), user: LtiUtils.get_user_id(params) })
      return nil unless lti_session.any?
      return lti_session.first.user
    end
    devise_current_user
  end
end
