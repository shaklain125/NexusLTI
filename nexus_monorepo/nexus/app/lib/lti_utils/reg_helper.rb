module LtiUtils
  class << self
    def consumer_url(registration_result)
      url = registration_result[:return_url]
      url = add_param(url, 'tool_proxy_guid', registration_result[:tool_proxy_uuid])
      add_param(url, 'status', registration_result[:status] == 'success' ? 'success' : 'error')
    end

    def auto_reg_format_caps(services, parameters)
      services = HashHelper.snake_case_sym_obj(services)

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

      { parameters: new_parameters, services: new_services }.symbolize_keys
    end

    def create_reg_obj(params, controller)
      registration_request = models.generate_message(params)
      LtiRegistration.new(
        registration_request_params: registration_request.post_params,
        tool_proxy_json: LtiToolProxyRegistration.new(registration_request, controller).tool_proxy.as_json
      )
    rescue StandardError
      raise LtiRegistration::Error, :invalid
    end

    def create_and_save_reg_obj(params, controller)
      reg = create_reg_obj(params, controller)
      reg.save!
      reg
    rescue StandardError
      raise LtiRegistration::Error, :invalid
    end

    def get_services_and_params(reg)
      tcp = reg.tool_consumer_profile
      tcp_url = tcp.id || reg.registration_request.tc_profile_url

      exclude_cap = [
        LtiUtils.models_all::Messages::BasicLTILaunchRequest::MESSAGE_TYPE,
        LtiUtils.models_all::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE
      ]

      capabilities = tcp.capability_offered.each_with_object({ parameters: [] }) do |cap, hash|
        hash[:parameters] << cap unless exclude_cap.include? cap
      end

      services = tcp.services_offered.each_with_object([]) do |service, col|
        next if service.id.include? 'ToolProxy.collection'
        name = service.id.split(':').last.split('#').last
        col << {
          name: name,
          service: "#{tcp_url}##{name}",
          actions: service.actions
        }
      end

      HashHelper.snake_case_symbolize({ capabilities: capabilities, services: services })
    end

    def save_services_and_params(reg, services, parameters)
      tool_services = services.map do |_, v|
        LtiUtils.models_all::RestServiceProfile.new(
          service: v['id'],
          action: [*JSON.parse("{\"a\":#{v['actions']}}")['a']]
        )
      end

      tool_proxy = reg.tool_proxy
      tool_profile = tool_proxy.tool_profile
      tool_proxy.security_contract.tool_service = tool_services if tool_services.present?

      parameters = parameters.map do |var, val|
        LtiUtils.models_all::Parameter.new(name: val['name'], variable: var)
      end

      tool_profile.resource_handler.each do |rh|
        rh.message.each { |mh| mh.parameter = mh.parameter | parameters }
      end

      reg.update(tool_proxy_json: tool_proxy.to_json)
    end

    def register_tool_proxy(reg, controller)
      LtiToolProxyRegistration.register(reg, controller)
      LtiRegistration.delete_all
      { success: true }.symbolize_keys
    rescue IMS::LTI::Errors::ToolProxyRegistrationError => e
      error = {
        tool_proxy_guid: reg.tool_proxy.tool_proxy_guid,
        response_status: e.response_status,
        response_body: e.response_body
      }
      { success: false, error: error }.symbolize_keys
    end
  end
end
