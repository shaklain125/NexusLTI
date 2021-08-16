module LtiRegHelper
  def lti_reg_before
    @is_lti = false
    @is_lti_error = false
    @is_lti_reg = true
  end

  def session_exists?
    !session[:session_id].nil?
  end

  def disable_xframe_header
    response.headers.except! 'X-Frame-Options'
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
