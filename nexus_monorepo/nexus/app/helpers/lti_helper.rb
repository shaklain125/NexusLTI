module LtiHelper
  def handle_lti_error(ex)
    @is_lti_error = true
    disable_xframe_header_lti
    @error = LtiUtils::ErrorHandlers.lti_error(ex)

    if ex.error == :invalid_origin
      exit_lti unless @is_student
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

    @is_lti_launch = LtiLaunch.launch_valid?(LtiUtils.models.parsed_lti_message(request))
    @is_lms_origin = LtiUtils::Origin.lms_origin?(request)
    @is_lms_or_launch = @is_lti_launch || @is_lms_origin

    if @is_lms_or_launch
      params.delete(:lti_token)
    else
      params[:lti_token] = LtiUtils::Token.get_cookie_token(cookies, session)
    end

    @is_teacher = LtiUtils::LtiRole.teacher?(params)
    @is_student = LtiUtils::LtiRole.student?(params)

    is_invalid_lti_role = !@is_teacher && !@is_student && !LtiUtils::Token.invalid?(params)
    params.delete(:lti_token) if !@is_lms_or_launch && is_invalid_lti_role

    @is_lti = LtiUtils::Token.exists?(params)

    contr_act = { controller_name: controller_name, action_name: action_name }
    @is_config_generator = LtiUtils::Token.from_generator?(params, **contr_act)
    @is_manage_assignment = LtiUtils::Token.from_manage_assignment?(params, **contr_act)
    @is_submission = LtiUtils::Token.from_submission?(params, **contr_act)

    @aid, @cid = LtiUtils::Token.get_conf(params, :aid, :cid)
    @cid_course = LtiUtils::Session.get_course(params)
    @submission_path = new_submission_path(aid: @aid) if @is_submission

    @manage_only_current_cid = LtiUtils::Session.manage_only_current_cid?
    @manage_only_current_aid = LtiUtils::Session.manage_only_current_aid?
    @allow_course_delete = LtiUtils::Session.allow_course_delete?

    LtiUtils::Token.set_flashes(flash, LtiUtils::Token.get_flashes!(self)) if LtiUtils::Token.exists_and_valid?(params)

    validate_token unless @is_lms_or_launch
    block_controllers unless @is_lms_or_launch
  end

  def lti_request?
    return if controller_name.to_sym == :lti_registration
    is_same_origin = LtiUtils::Origin.same_origin?(request)
    valid_methods = %w[POST PATCH].include?(request.method)
    token = {}
    token[:lti_token] = LtiUtils::Token.get_cookie_token(cookies, session)
    is_student = LtiUtils::LtiRole.student?(token)
    is_teacher = LtiUtils::LtiRole.teacher?(token)
    is_valid_lti_role = is_student || is_teacher
    is_valid_lti_role && valid_methods && is_same_origin
  end

  def validate_token
    LtiUtils::Token.raise_if_invalid(params)
    LtiUtils::Session.raise_if_course_not_found(@cid_course) if @cid && request.referrer
    LtiUtils::LtiRole.if_student_show_student_pages_raise(self)
    LtiUtils::Origin.raise_if_null_referrer_and_lti(self)
    LtiUtils::LtiRole.if_teacher_show_teacher_pages_raise(self)
    LtiUtils::Session.raise_if_invalid_session(self)
    LtiUtils::Origin.raise_if_invalid_token_ip(self)
    LtiUtils::Token.raise_if_exists(params) unless current_user
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
    LtiUtils::Session.logout_session(self) unless LtiUtils::Token.invalid?(params)
    sign_out(current_user)
    LtiUtils::Token.delete_cookie_token(cookies, session)
  end

  def disable_xframe_header_lti
    LtiUtils::Origin.disable_xframe_header(response) if @is_lti || @is_lti_reg || @is_lti_error || @is_lti_reg_error
  end
end
