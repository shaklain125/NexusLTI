module LtiRegHelper
  def lti_reg_before
    @is_lti = false
    @is_lti_error = false
    @is_lti_reg = true
    raise LtiRegistration::Error, :invalid_registration if invalid_req?
  end

  def session_exists?
    !session[:session_id].nil?
  end

  def lti_reg_req?
    !invalid_req?
  end

  def invalid_req?
    is_lms = LtiUtils::Origin.check_if_is_lms_origin(request)
    is_valid_reg = LtiUtils::RegHelper.check_tc_profile_valid(params) # valid only when is lms
    is_same_origin = LtiUtils::Origin.same_origin?(request)
    (is_same_origin && is_valid_reg) || ((!is_same_origin || is_lms) && !is_valid_reg)
  end

  def register_proxy(reg)
    reg_result = LtiUtils::RegHelper.register_tool_proxy(reg, self)
    if reg_result[:success]
      render 'lti_registration/success_msg', status: 200
    else
      @error = reg_result[:error]
      render 'lti_registration/submit_proxy', status: 200
    end
  end
end
