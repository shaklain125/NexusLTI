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
    @referrer = request.referrer
    @session_id = session[:session_id]

    is_lms_referer = LtiUtils.check_if_referrer_is_not_lms(request, params)
    student_ref_page = LtiUtils::LtiRole.if_student_and_referer_valid_raise(params, request, controller_name, action_name)
    teacher_ref_page = LtiUtils::LtiRole.if_teacher_and_referer_valid_raise(params, request, controller_name, action_name)
    is_ref_page = (@is_teacher && teacher_ref_page) || (@is_student && student_ref_page)

    unless is_ref_page
      if cookies[:lti_token].nil?
        LtiUtils.raise_if_not_cookie_token_present_and_lti(cookies) if @is_student
      elsif params[:lti_token].nil?
        params[:lti_token] = LtiUtils.get_cookie_token(cookies)
      else
        params.delete(:lti_token)
      end
    end

    @is_lti = LtiUtils.contains_token_param(params)
    @is_teacher = LtiUtils.verify_teacher(params)
    @is_student = LtiUtils.verify_student(params)

    validate_token unless is_lms_referer
  end

  def lti_request?
    http_referer_uri = LtiUtils.http_referer_uri(request)
    same_host_and_referrer = LtiUtils.check_host(request.referrer, [LtiUtils.get_host(request.headers['origin'])])
    http_referer_and_host = http_referer_uri ? request.host == http_referer_uri.host : false
    valid_methods = %w[POST PATCH].include?(request.method)
    is_student = LtiUtils.verify_student(cookies)
    is_teacher = LtiUtils.verify_teacher(cookies)
    is_teacher_or_student = is_student || is_teacher
    is_teacher_or_student && valid_methods && same_host_and_referrer && http_referer_and_host
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
    unless LtiUtils.invalid_token(params)
      return nil if @is_teacher && !LtiUtils.get_user_id(params)
      lti_session = LtiSession.where({ lti_tool: LtiUtils.get_tool_id(params), user: LtiUtils.get_user_id(params) })
      return nil unless lti_session.any?
      return lti_session.first.user
    end
    devise_current_user
  end

  def default_url_options(options = {})
    # puts('DEFAULT PARAMS--------------------------------')
    # puts(action_name)
    # puts(params)
    # options[:lti_token] = params[:lti_token] unless LtiUtils.invalid_token(params)
    options
  end
end
