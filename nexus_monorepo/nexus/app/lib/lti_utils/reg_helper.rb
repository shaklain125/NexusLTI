module LtiUtils
  class RegHelper
    class << self
      def reg_format_caps(services, parameters)
        services = HashHelper.snake_case_sym_obj(services)

        new_services = services.each_with_object({}) do |s, h|
          h[s[:name].to_s] = {
            enabled: true,
            id: s[:service],
            actions: s[:actions].to_json
          }.stringify_keys
        end

        new_parameters = parameters.each_with_object({}) do |p, h|
          h[p.to_s] = {
            enabled: true,
            name: p.downcase.gsub('.', '_')
          }.stringify_keys
        end

        { parameters: new_parameters, services: new_services }.symbolize_keys
      end

      def get_and_save_reg_caps(reg)
        caps = get_services_and_params(reg)
        caps = reg_format_caps(caps[:services], caps[:capabilities][:parameters])
        save_services_and_params(reg, caps[:services], caps[:parameters])
      end

      def check_tc_profile_valid(params)
        LtiUtils.services.get_tc_profile_from_tp_reg_service(LtiUtils.models.generate_message(params))
        true
      rescue StandardError
        false
      end

      ## Create REG

      def create_reg_obj(params, controller)
        registration_request = LtiUtils.models.generate_message(params)
        LtiRegistration.new(
          registration_request_params: registration_request.post_params,
          tool_proxy_json: LtiUtils::ToolProxyReg.new(registration_request, controller).tool_proxy.as_json
        )
      rescue StandardError => e
        raise LtiRegistration::Error, e
      end

      def create_and_save_reg_obj(params, controller)
        reg = create_reg_obj(params, controller)
        begin
          reg.save!
          reg
        rescue StandardError
          raise LtiRegistration::Error, :failed_to_save_proxy
        end
      end

      ## RH

      def find_local_rh_by_path(path)
        route = Rails.application.routes.recognize_path(path, method: 'POST')
        return {} unless route
        found_rh = LTI_RESOURCE_HANDLERS.select do |rh|
          l_route = rh[:message][:route]
          contr = l_route[:controller] == route[:controller]
          act = l_route[:action] == route[:action]
          contr && act
        end
        found_rh.first if found_rh.any?
      rescue StandardError
        {}
      end

      def filter_out_rh(params, reg)
        rhandlers = params[:rh] ? params[:rh].select { |k, v| v[:enabled] && !find_local_rh_by_path(k).empty? } : {}
        if rhandlers.empty?
          reg.destroy
          raise LtiRegistration::Error, :no_resource_handlers_selected
        end
        get_rh_from_reg(reg).select do |rh|
          f = false
          rh.message.each do |mh|
            f = true if !f && rhandlers.keys.include?(mh.path)
          end
          f
        end
      end

      def reg_update_rh(rh, reg)
        tool_proxy = reg.tool_proxy
        tool_proxy.tool_profile.resource_handler = rh
        reg.update(tool_proxy_json: tool_proxy.to_json)
      end

      def filter_out_and_reg_update_rh(params, reg)
        reg_update_rh(filter_out_rh(params, reg), reg)
      end

      def get_rh_from_reg(reg)
        reg.tool_proxy.tool_profile.resource_handler
      end

      def get_rh_name_path_list(reg, controller)
        list = get_rh_from_reg(reg).each_with_object([]) do |rh, l|
          rh.message.each do |mh|
            pth = mh.path
            route = Rails.application.routes.recognize_path(pth, method: 'POST')
            l << {
              name: rh.resource_name.default_value,
              path: pth,
              route: route,
              full_path: Rails.application.routes.url_for(
                **route,
                host: controller.request.host_with_port
              )
            }
          end
        end
        list.to_a
      end

      def all_caps_rh?(path)
        all_caps = find_local_rh_by_path(path)[:all_capabilities]
        all_caps.nil? ? false : all_caps == true
      end

      def get_all_rh_required_caps(reg)
        all_caps = false
        caps = get_rh_from_reg(reg).each_with_object(Set.new) do |rh, s|
          rh.message.each do |mh|
            all_caps = true if !all_caps && all_caps_rh?(mh.path)
            s.merge(mh.enabled_capability)
          end
        end
        [caps.to_a, all_caps]
      end

      ## Get and Set Caps, Register Proxy

      def get_services_and_params(reg)
        tcp = reg.tool_consumer_profile
        tcp_url = tcp.id || reg.registration_request.tc_profile_url

        exclude_cap = [
          LtiUtils.models.all::Messages::BasicLTILaunchRequest::MESSAGE_TYPE,
          LtiUtils.models.all::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE
        ]
        caps, all_caps = get_all_rh_required_caps(reg)
        caps = tcp.capability_offered if all_caps

        capabilities = caps.each_with_object({ parameters: [] }) do |cap, hash|
          hash[:parameters] << cap unless exclude_cap.include?(cap)
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
          LtiUtils.models.all::RestServiceProfile.new(
            service: v['id'],
            action: [*JSON.parse("{\"a\":#{v['actions']}}")['a']]
          )
        end

        tool_proxy = reg.tool_proxy
        tool_profile = tool_proxy.tool_profile
        tool_proxy.security_contract.tool_service = tool_services if tool_services.present?

        parameters = parameters.map do |var, val|
          LtiUtils.models.all::Parameter.new(name: val['name'], variable: var)
        end

        tool_profile.resource_handler.each do |rh|
          rh.message.each do |mh|
            if all_caps_rh?(mh.path)
              mh.parameter = mh.parameter | parameters
            else
              parameters.each do |p|
                mh.parameter << p if mh.enabled_capability.include?(p.variable)
              end
            end
          end
        end

        reg.update(tool_proxy_json: tool_proxy.to_json)
      end

      def register_tool_proxy(reg, controller)
        LtiUtils::ToolProxyReg.register(reg, controller)
        reg.destroy
        { success: true }.symbolize_keys
      rescue LtiUtils.errors.all::ToolProxyRegistrationError => e
        error = {
          tool_proxy_guid: reg.tool_proxy.tool_proxy_guid,
          response_status: e.response_status,
          response_body: e.response_body
        }
        { success: false, error: error }.symbolize_keys
      end
    end
  end
end
