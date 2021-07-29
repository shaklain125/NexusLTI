class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception
  protect_from_forgery with: :null_session
  # Devise strong parameters
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :lti_auth

  rescue_from LtiLaunch::Unauthorized do |ex|
    @error = "Authentication failed with: #{case ex.error
                                            when :invalid_signature
                                              'The OAuth Signature was Invalid'
                                            when :invalid_nonce
                                              'The nonce has already been used'
                                            when :request_to_old
                                              'The request is to old'
                                            else
                                              'Unknown Error'
                                            end}"
    @message = IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    @header = SimpleOAuth::Header.new(:post, request.url, @message.post_params, consumer_key: @message.oauth_consumer_key, consumer_secret: 'secret', callback: 'about:blank')
    render "lti/launch_error", status: 200
  end

  protected

  def lti_auth
    LtiHelper.invalid_token_raise(params)
  end

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
    unless LtiHelper.invalid_token(params)
      lti_session = LtiSession.find_by_lti_tool_id(LtiHelper.get_tool_id(params))
      return nil unless lti_session
      return lti_session.user
    end
    devise_current_user
  end

  def default_url_options(options = {})
    # puts('DEFAULT PARAMS--------------------------------')
    # puts(action_name)
    # puts(params)
    options[:lti_token] = params[:lti_token] unless LtiHelper.invalid_token(params)
    options
  end
end
