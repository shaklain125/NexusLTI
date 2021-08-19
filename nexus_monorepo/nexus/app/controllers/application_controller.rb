class ApplicationController < ActionController::Base
  include LtiHelper
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception
  protect_from_forgery with: :null_session
  # Devise strong parameters
  before_action :configure_permitted_parameters, if: :devise_controller?

  ## LTI
  before_action :lti_auth
  skip_before_action :verify_authenticity_token, if: :lti_request?
  after_action :disable_xframe_header_lti
  rescue_from LtiLaunch::Error, with: :handle_lti_error
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
    return LtiUtils::Session.get_current_user(params) unless LtiUtils.invalid_token(params)
    if @is_lti_reg || @is_lti_reg_error
      sign_out(devise_current_user)
      return nil
    end
    devise_current_user
  end

  def redirect_to(*args, **kwargs)
    LtiUtils::Session.set_http_flash(flash, request, params, cookies, session)
    super(*args, **kwargs)
  end
end
