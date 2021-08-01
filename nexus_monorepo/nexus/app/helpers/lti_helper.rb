module LtiHelper
  class << self
    def test; end
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

  def parsed_lti_message(request)
    lti_message = IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    lti_message.launch_url = request.url
    lti_message
  end

  def lti_authentication
    @lti_launch = LtiLaunch.check_launch(parsed_lti_message(request))
  end

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
    url = add_param(url, 'tool_proxy_guid', registration_result[:tool_proxy_uuid])
    url = if registration_result[:status] == 'success'
            add_param(url, 'status', 'success')
          else
            add_param(url, 'status', 'error')
          end
    redirect_to url
  end

  def add_param(url, param_name, param_value)
    uri = URI(url)
    params = URI.decode_www_form(uri.query || '') << [param_name, param_value]
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
