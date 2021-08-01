module LtiHelper
  class << self
    def test; end
  end

  def lti_auth
    @referrer = request.referrer
    @session_id = session[:session_id]

    is_lms_referer = LtiUtils.check_if_referrer_is_not_lms(request, params)
    student_ref_page = LtiUtils::LtiRole.if_student_and_referer_valid_raise(params, request, controller_name, action_name)
    teacher_ref_page = LtiUtils::LtiRole.if_teacher_and_referer_valid_raise(params, request, controller_name, action_name)
    is_ref_page = (@is_teacher && teacher_ref_page) || (@is_student && student_ref_page)

    unless is_ref_page
      if !LtiUtils.cookie_token_exists(cookies, session)
        LtiUtils.raise_if_not_cookie_token_present_and_lti(cookies, session) if @is_student
      elsif params[:lti_token].nil?
        params[:lti_token] = LtiUtils.get_cookie_token(cookies, session)
      else
        params.delete(:lti_token)
      end
    end

    @is_lti = LtiUtils.contains_token_param(params)
    @is_teacher = LtiUtils.verify_teacher(params)
    @is_student = LtiUtils.verify_student(params)
    @is_config_generator = LtiUtils.from_generator(params) && !(controller_name.to_sym == :lti && (action_name.to_sym == :configure || action_name.to_sym == :login))
    @is_manage_assignment = LtiUtils.from_manage_assignment(params) && !(controller_name.to_sym == :lti && action_name.to_sym == :manage_assignment)
    @is_submission = LtiUtils.from_submission(params) && !(controller_name.to_sym == :submission && action_name.to_sym == :new)
    @submission_path = new_submission_path(aid: LtiUtils.get_submission_token(params)[:aid]) if @is_submission

    validate_token unless is_lms_referer
    block_controllers unless is_lms_referer
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

  def validate_token
    @is_lti_error = true
    LtiUtils.invalid_token_raise(params)
    LtiUtils::LtiRole.if_student_show_student_pages_raise(params, controller_name)
    LtiUtils.raise_if_null_referrer_and_lti(request, params)
    LtiUtils.raise_if_session_cookie_check_and_lti(cookies, session, request, params)
    LtiUtils.raise_if_invalid_token_ip(request, params)
    @is_lti_error = false
  end

  def block_controllers
    valid = true

    case controller_name.to_sym
    when :sessions
      valid = false if current_user
    end

    raise LtiLaunch::Unauthorized, :invalid if !valid && LtiUtils.contains_token_param(params)
  end

  # ------------------LTI LAUNCH----------------------- #

  def parsed_lti_message(request)
    lti_message = IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    lti_message.launch_url = request.url
    lti_message
  end

  def lti_authentication
    @lti_launch = LtiLaunch.check_launch(parsed_lti_message(request))
  end

  # ------------------LTI REG----------------------- #

  def disable_xframe_header
    response.headers.except! 'X-Frame-Options'
  end

  def registration_request
    registration_request = IMS::LTI::Models::Messages::Message.generate(params)
    @registration = LtiRegistration.new(
      registration_request_params: registration_request.post_params,
      tool_proxy_json: LtiToolProxyRegistration.new(registration_request, self).tool_proxy.as_json
    )
    @registration.save!
  end

  def register_proxy(registration)
    LtiToolProxyRegistration.register(registration, self)
  end

  def redirect_to_consumer(registration_result)
    url = registration_result[:return_url]
    url = LtiUtils.add_param(url, 'tool_proxy_guid', registration_result[:tool_proxy_uuid])
    url = LtiUtils.add_param(url, 'status', registration_result[:status] == 'success' ? 'success' : 'error')
    redirect_to url
  end
end
