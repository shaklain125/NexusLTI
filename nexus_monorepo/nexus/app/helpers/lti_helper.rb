module LtiHelper
  class << self
    def check_lti_tool(id)
      !LtiTool.where(id: id).empty?
    end
  end

  def lti_authentication
    lti_message = IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    lti_message.launch_url = request.url
    @lti_launch = LtiLaunch.check_launch(lti_message)
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
