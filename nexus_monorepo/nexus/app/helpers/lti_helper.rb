module LtiHelper
  def handle_lti_error(ex)
    @is_lti_error = true
    @error = LtiUtils::ErrorHandlers.lti_error(ex)

    # Exit LTI on all other messages except the following
    no_exit_err_msgs = [
      :invalid_lti_role_access,
      :invalid_page_access,
      :invalid_aid,
      :assigment_not_started
    ]
    no_exit_err_msgs << :invalid_origin if @is_student
    exit_lti unless no_exit_err_msgs.include?(ex.error)

    if ex.error == :invalid_origin
      redirect_to root_path
      return
    end

    render "lti/error", status: 200
  end

  def handle_lti_reg_error(ex)
    @is_lti_reg_error = true
    @error = LtiUtils::ErrorHandlers.lti_reg_error(ex)
    render "lti_registration/error", status: 200
  end

  def lti_auth
    return if controller_name.to_sym == :lti_registration

    @is_lti_error = false
    @referrer = request.referrer
    @session_id = session[:session_id]

    @is_lti_launch = LtiLaunch.check_launch_bool(LtiUtils.models.parsed_lti_message(request))
    @is_lms_origin = LtiUtils::Origin.check_if_is_lms_origin(request)
    @is_lms_referrer = LtiUtils::Origin.check_if_is_lms_referrer(request)
    @is_lms_or_launch = @is_lti_launch || @is_lms_origin

    if @is_lms_or_launch
      params.delete(:lti_token)
    else
      params[:lti_token] = LtiUtils.get_cookie_token(cookies, session)
    end

    @is_teacher = LtiUtils::LtiRole.verify_teacher(params)
    @is_student = LtiUtils::LtiRole.verify_student(params)

    @student_ref_page = @is_student && LtiUtils::LtiRole.valid_student_referer(controller_name, action_name)
    @teacher_ref_page = @is_teacher && LtiUtils::LtiRole.valid_teacher_referer(controller_name, action_name)
    @is_ref_page = @teacher_ref_page || @student_ref_page

    @is_valid_student_page = @is_student && LtiUtils::LtiRole.valid_student_pages(controller_name)

    if @is_ref_page
      valid = true
      if LtiUtils::Origin.lms_hosts.any?
        valid = false if !@is_lms_referrer && !@is_valid_student_page
      elsif !@is_valid_student_page
        valid = false
      end

      unless valid
        params.delete(:lti_token)
        @is_teacher = false
        @is_student = false
        @is_ref_page = false
        @student_ref_page = false
        @teacher_ref_page = false
      end
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
    http_referer_uri = LtiUtils::URIHelper.http_referer_uri(request)
    same_host_and_referrer = LtiUtils::URIHelper.check_host(request.referrer, [LtiUtils::URIHelper.get_host(request.headers['origin'])])
    http_referer_and_host = http_referer_uri ? request.host == http_referer_uri.host : false
    valid_methods = %w[POST PATCH].include?(request.method)
    token = {}
    token[:lti_token] = LtiUtils.get_cookie_token(cookies, session)
    is_student = LtiUtils::LtiRole.verify_student(token)
    is_teacher = LtiUtils::LtiRole.verify_teacher(token)
    is_valid_lti_role = is_student || is_teacher
    is_valid_lti_role && valid_methods && same_host_and_referrer && http_referer_and_host
  end

  def validate_token
    LtiUtils.invalid_token_raise(params)
    LtiUtils::LtiRole.if_student_show_student_pages_raise(params, controller_name)
    LtiUtils::Origin.raise_if_null_referrer_and_lti(request, params)
    LtiUtils::Session.raise_if_invalid_session(cookies, session, request, params)
    LtiUtils::Origin.raise_if_invalid_token_ip(request, params)
  end

  def block_controllers
    valid = true

    case controller_name.to_sym
    when :sessions
      valid = false if current_user
    end

    raise LtiLaunch::Error, :invalid_page_access if !valid && @is_lti
  end

  def exit_lti
    LtiUtils::Session.logout_session(params, cookies, session) unless LtiUtils.invalid_token(params)
    sign_out(current_user)
    LtiUtils.delete_cookie_token(cookies, session)
  end
end
