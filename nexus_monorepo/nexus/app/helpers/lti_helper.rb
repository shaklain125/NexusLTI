module LtiHelper
  def handle_lti_error(ex)
    @is_lti_error = true
    disable_xframe_header_lti
    @error = LtiUtils::ErrorHandlers.lti_error(ex)

    # Exit LTI on all other messages except the following
    no_exit_err_msgs = [
      :invalid_lti_role_access,
      :invalid_page_access,
      :invalid_aid,
      :assigment_not_started,
      :invalid_lti_user,
      :invalid_lti_role_teacher_access,
      :course_not_found
    ]
    no_exit_err_msgs << :invalid_origin if @is_student
    # no_exit_err_msgs << :invalid_origin if @is_teacher
    exit_lti unless no_exit_err_msgs.include?(ex.error)

    if ex.error == :invalid_origin
      redirect_to root_path
      return
    end

    render "lti/error", status: 200
  end

  def handle_lti_reg_error(ex)
    @is_lti_reg_error = true
    disable_xframe_header_lti
    @error = LtiUtils::ErrorHandlers.lti_reg_error(ex)
    render "lti_registration/error", status: 200
  end

  def lti_auth
    return if controller_name.to_sym == :lti_registration

    @is_lti_error = false
    @referrer = request.referrer
    @session_id = session[:session_id]

    @is_lti_launch = LtiLaunch.check_launch?(LtiUtils.models.parsed_lti_message(request))
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

    @is_valid_student_page = @is_student && LtiUtils::LtiRole.valid_student_pages(params, controller_name, action_name)

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
    @is_config_generator = LtiUtils.from_generator?(params) && !(controller_name.to_sym == :lti && [:configure, :login].include?(action_name.to_sym))
    @is_manage_assignment = LtiUtils.from_manage_assignment?(params) && !(controller_name.to_sym == :lti && action_name.to_sym == :manage_assignment)
    @is_submission = LtiUtils.from_submission?(params) && !(controller_name.to_sym == :submission && action_name.to_sym == :new)
    @submission_path = new_submission_path(aid: LtiUtils.get_submission_token(params)[:aid]) if @is_submission
    @cid = LtiUtils.get_conf(params)[:cid]
    @cid_course = LtiUtils::Session.get_course(params)

    LtiUtils.set_flashes(flash, @is_lti ? LtiUtils.get_flashes!(params, cookies, session) : [])

    validate_token unless @is_lms_or_launch
    block_controllers unless @is_lms_or_launch
  end

  def lti_request?
    return if controller_name.to_sym == :lti_registration
    is_same_origin = LtiUtils::Origin.same_origin?(request)
    valid_methods = %w[POST PATCH].include?(request.method)
    token = {}
    token[:lti_token] = LtiUtils.get_cookie_token(cookies, session)
    is_student = LtiUtils::LtiRole.verify_student(token)
    is_teacher = LtiUtils::LtiRole.verify_teacher(token)
    is_valid_lti_role = is_student || is_teacher
    is_valid_lti_role && valid_methods && is_same_origin
  end

  def validate_token
    LtiUtils.invalid_token_raise(params)
    LtiUtils::Session.raise_if_course_not_found(@cid_course) if @cid && request.referrer
    LtiUtils::LtiRole.if_student_show_student_pages_raise(params, controller_name, action_name)
    LtiUtils::Origin.raise_if_null_referrer_and_lti(request, params)
    LtiUtils::LtiRole.if_teacher_show_teacher_pages_raise(params, controller_name, action_name)
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

  def disable_xframe_header_lti
    LtiUtils::Origin.disable_xframe_header(response) if @is_lti || @is_lti_reg || @is_lti_error || @is_lti_reg_error
  end
end
