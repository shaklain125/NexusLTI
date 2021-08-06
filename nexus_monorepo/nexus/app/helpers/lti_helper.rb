module LtiHelper
  def handle_lti_error(ex)
    @is_lti_error = true
    @error = "Authentication failed with: #{case ex.error
                                            when :invalid_signature
                                              'The OAuth Signature was Invalid'
                                            when :invalid_nonce
                                              'The nonce has already been used'
                                            when :request_to_old
                                              'The request is to old'
                                            when :missing_arguments_or_unknown
                                              'Missing arguments or Invalid request'
                                            when :invalid_origin
                                              'Invalid Origin'
                                            when :invalid_lti_role_access
                                              'Invalid LTI role access'
                                            when :invalid_aid
                                              'Assignment not set'
                                            when :invalid_page_access
                                              'Page access disabled'
                                            else
                                              "Unknown Error: #{ex.error.to_s.underscore.titleize}"
                                            end}"
    @message = LtiUtils.models.generate_message(request.request_parameters)
    @header = SimpleOAuth::Header.new(:post, request.url, @message.post_params, consumer_key: @message.oauth_consumer_key, consumer_secret: 'secret', callback: 'about:blank')
    render "lti/launch_error", status: 200
  end

  def lti_auth
    return if controller_name.to_sym == :lti_registration

    @is_lti_error = false
    @referrer = request.referrer
    @session_id = session[:session_id]

    @is_lti_launch = LtiLaunch.check_launch_bool(parsed_lti_message(request))
    @is_lms_origin = LtiUtils.check_if_is_lms_origin(request)
    @is_lms_referrer = LtiUtils.check_if_is_lms_referrer(request)
    @is_lms_or_launch = @is_lti_launch || @is_lms_origin

    if @is_lms_or_launch
      params.delete(:lti_token)
    else
      params[:lti_token] = LtiUtils.get_cookie_token(cookies, session)
    end

    @is_teacher = LtiUtils.verify_teacher(params)
    @is_student = LtiUtils.verify_student(params)

    @student_ref_page = @is_student && LtiUtils::LtiRole.valid_student_referer(params, request, controller_name, action_name)
    @teacher_ref_page = @is_teacher && LtiUtils::LtiRole.valid_teacher_referer(params, request, controller_name, action_name)
    @is_ref_page = @teacher_ref_page || @student_ref_page

    @is_valid_student_page = @is_student && LtiUtils::LtiRole.valid_student_pages(controller_name)

    if @is_ref_page && LtiUtils.lms_hosts.any? && !@is_lms_referrer && !@is_valid_student_page
      params.delete(:lti_token)
      @is_teacher = false
      @is_student = false
      @is_ref_page = false
      @student_ref_page = false
      @teacher_ref_page = false
    end

    @is_lti = LtiUtils.contains_token_param(params)
    @is_config_generator = LtiUtils.from_generator(params) && !(controller_name.to_sym == :lti && (action_name.to_sym == :configure || action_name.to_sym == :login))
    @is_manage_assignment = LtiUtils.from_manage_assignment(params) && !(controller_name.to_sym == :lti && action_name.to_sym == :manage_assignment)
    @is_submission = LtiUtils.from_submission(params) && !(controller_name.to_sym == :submission && action_name.to_sym == :new)
    @submission_path = new_submission_path(aid: LtiUtils.get_submission_token(params)[:aid]) if @is_submission

    validate_token unless @is_lms_or_launch
    block_controllers unless @is_lms_or_launch
  end

  def lti_request?
    return if controller_name.to_sym == :lti_registration
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
    LtiUtils.invalid_token_raise(params)
    LtiUtils::LtiRole.if_student_show_student_pages_raise(params, controller_name)
    LtiUtils.raise_if_null_referrer_and_lti(request, params)
    LtiUtils.raise_if_session_cookie_check_and_lti(cookies, session, request, params)
    LtiUtils.raise_if_invalid_token_ip(request, params)
  end

  def block_controllers
    valid = true

    case controller_name.to_sym
    when :sessions
      valid = false if current_user
    end

    raise LtiLaunch::Unauthorized, :invalid_page_access if !valid && @is_lti
  end

  # ------------------LTI Session----------------------- #

  def create_teacher(email, name)
    u = User.find_by_email(email)
    u ||= User.create(email: email,
                      password: '12345678',
                      password_confirmation: '12345678',
                      name: name,
                      admin: true)
    u
  end

  def create_student(email, name)
    u = User.find_by_email(email)
    u ||= User.create(email: email,
                      password: '12345678',
                      password_confirmation: '12345678',
                      name: name)
    u
  end

  def create_session(user)
    return nil unless user
    session_exists = LtiSession.where({ user: user.id })
    session_exists.delete_all if session_exists.any?
    LtiSession.create(lti_tool: LtiTool.find(LtiUtils.get_tool_id(params)), user: user)
  end

  # ------------------LTI LAUNCH----------------------- #

  def parsed_lti_message(request)
    lti_message = LtiUtils.models.generate_message(request.request_parameters)
    lti_message.launch_url = request.url
    lti_message
  end

  def lti_authentication
    @lti_launch = LtiLaunch.check_launch(parsed_lti_message(request))
  end
end
