class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception
  protect_from_forgery with: :null_session
  # Devise strong parameters
  before_action :configure_permitted_parameters, if: :devise_controller?

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

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) do |u|
      u.permit(:email, :first_name, :last_name, :student_id, :password, :password_confirmation)
    end
    # Use the below instead for devise versions > 4.1
    # devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :first_name, :last_name, :student_id, :password, :password_confirmation])
  end
end
