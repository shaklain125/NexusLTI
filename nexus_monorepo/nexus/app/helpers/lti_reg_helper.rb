module LtiRegHelper
  def session_exists?
    !session[:session_id].nil?
  end

  def disable_xframe_header
    response.headers.except! 'X-Frame-Options'
  end

  def handle_lti_reg_error(ex)
    @is_lti_reg_error = true
    @error = "Reason: #{case ex.error
                        when :missing_product_instance
                          'Missing Product Instance Config'
                        else
                          'Unknown Error'
                        end}"
    render "lti_registration/error", status: 200
  end

  def register_proxy(reg)
    reg_result = LtiUtils.register_tool_proxy(reg, self)
    if reg_result[:success]
      render 'lti_registration/success_msg', status: 200
    else
      @error = reg_result[:error]
      render 'lti_registration/submit_proxy', status: 200
    end
  end
end
