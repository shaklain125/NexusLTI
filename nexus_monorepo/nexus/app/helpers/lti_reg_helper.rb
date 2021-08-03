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
                        when :already_registered
                          'Tool Proxy Already Registered'
                        when :unsupported_capabilities_error
                          'Unsupported Capabilities'
                        else
                          'Unknown Error'
                        end}"
    render "lti_registration/error", status: 200
  end

  def interactive_registration
    if session_exists?
      session[:lti_reg_token] = LtiUtils.encrypt_json({ reg_params: params })
      reg_generate(params)
    else
      reg_request(params)
    end
    registration_main
  end

  # --------------- AUTO REG ---------------

  def render_nexus_success_msg
    render 'lti_registration/success_msg', status: 200
  end

  def auto_registration
    reg_request(params)
    registration_main
    auto_reg_format_caps(@services_offered, @capabilities[:parameters])
    save_caps(@registration, @services_offered, @capabilities)
    begin
      register_proxy(@registration)
      render_nexus_success_msg
    rescue IMS::LTI::Errors::ToolProxyRegistrationError => e
      @error = {
        tool_proxy_guid: registration.tool_proxy.tool_proxy_guid,
        response_status: e.response_status,
        response_body: e.response_body
      }
      render 'lti_registration/submit_proxy', status: 200
    end
  end

  def auto_reg_format_caps(services, parameters)
    services = LtiUtils::HashHelper.snake_case_sym_obj(services)

    new_services = {}
    new_parameters = {}

    services.each do |s|
      new_services[s[:name].to_s] = {
        enabled: true,
        id: s[:service],
        actions: s[:actions].to_json
      }.stringify_keys
    end

    parameters.each do |p|
      new_parameters[p.to_s] = {
        enabled: true,
        name: p.downcase.gsub('.', '_')
      }.stringify_keys
    end

    @capabilities = new_parameters
    @services_offered = new_services
  end

  # --------------- REG CORE ---------------

  def register_proxy(registration)
    LtiToolProxyRegistration.register(registration, self)
  end

  def reg_generate(params)
    registration_request = LtiUtils.models.generate_message(params)
    @registration = LtiRegistration.new(
      registration_request_params: registration_request.post_params,
      tool_proxy_json: LtiToolProxyRegistration.new(registration_request, self).tool_proxy.as_json
    )
  rescue StandardError
    raise LtiRegistration::Error, :invalid
  end

  def reg_request(params)
    reg_generate(params)
    @registration.save!
  rescue StandardError
    raise LtiRegistration::Error, :invalid
  end

  def registration_main
    tcp = @registration.tool_consumer_profile
    tcp_url = tcp.id || @registration.registration_request.tc_profile_url

    exclude_cap = [
      LtiUtils.models_all::Messages::BasicLTILaunchRequest::MESSAGE_TYPE,
      LtiUtils.models_all::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE
    ]

    @capabilities = tcp.capability_offered.each_with_object({ parameters: [] }) do |cap, hash|
      hash[:parameters] << cap unless exclude_cap.include? cap
    end

    @services_offered = tcp.services_offered.each_with_object([]) do |service, col|
      next if service.id.include? 'ToolProxy.collection'
      name = service.id.split(':').last.split('#').last
      col << {
        name: name,
        service: "#{tcp_url}##{name}",
        actions: service.actions
      }
    end
  end

  def save_caps(registration, services, parameters)
    tool_services = services.map do |_, v|
      actions = [*JSON.parse("{\"a\":#{v['actions']}}")['a']]
      LtiUtils.models_all::RestServiceProfile.new(service: v['id'], action: actions)
    end

    tool_proxy = registration.tool_proxy
    tool_profile = tool_proxy.tool_profile
    tool_proxy.security_contract.tool_service = tool_services if tool_services.present?
    tool_proxy.custom = nil

    rh = tool_profile.resource_handler.first
    mh = rh.message.first
    mh.parameter = parameters.map { |var, val| LtiUtils.models_all::Parameter.new(name: val['name'], variable: var) }

    registration.update(tool_proxy_json: tool_proxy.to_json)
  end

  def redirect_to_consumer(registration_result)
    url = registration_result[:return_url]
    url = LtiUtils.add_param(url, 'tool_proxy_guid', registration_result[:tool_proxy_uuid])
    url = LtiUtils.add_param(url, 'status', registration_result[:status] == 'success' ? 'success' : 'error')
    redirect_to url
  end
end
