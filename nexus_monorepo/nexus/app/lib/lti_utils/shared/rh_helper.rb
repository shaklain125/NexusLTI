module LtiUtils
  class RHHelper
    class << self
      ## Resource Handlers and LTI paths

      def resource_handlers
        LTI_RESOURCE_HANDLERS
      end

      def resource_handlers!
        handlers = []
        Dir[Rails.root.join('config', 'lti', 'resource_handlers', '*.json')].each do |rh|
          rh = File.read(rh)
          begin
            rh = JSON.parse(rh).with_indifferent_access
            rh.delete('$schema') if rh['$schema']
            handlers << rh
          rescue StandardError
            next
          end
        end
        handlers
      end

      def init_lti_paths!(router)
        resource_handlers.each do |rh|
          route = rh[:message][:route].symbolize_keys
          path = route.delete(:path) || ':controller/:action'
          router.post("lti/message/#{path}", route)
        end
      end

      ## SCHEMA AND ALL CAPS

      def schema
        rh_schema = Rails.root.join('config', 'lti', 'schema', 'resource_handler.json')
        return {} unless File.exist?(rh_schema)
        begin
          rh_schema = JSON.parse(File.read(rh_schema))
        rescue StandardError
          rh_schema = {}
        end
        rh_schema
      end

      def all_caps
        LTI_RH_ALL_CAPS
      end

      def all_caps!
        all_caps = HashHelper.nested_hash_val(schema, 'required_capabilities')
        HashHelper.nested_hash_val(all_caps, 'enum')
      end

      ## General

      def recognise_path(path)
        Rails.application.routes.recognize_path(path, method: 'POST')
      end

      def find_local_rh_by_path(path)
        route = recognise_path(path)
        return {} unless route
        found_rh = resource_handlers.select do |rh|
          l_route = rh[:message][:route]
          contr = l_route[:controller] == route[:controller]
          act = l_route[:action] == route[:action]
          contr && act
        end
        found_rh.first if found_rh.any?
      rescue StandardError
        {}
      end

      def all_caps_rh?(path)
        all_caps = find_local_rh_by_path(path)[:all_capabilities]
        all_caps.nil? ? false : all_caps == true
      end

      def get_rh_caps(path)
        is_all = all_caps_rh?(path)
        rh = find_local_rh_by_path(path)
        req_caps = rh[:message][:required_capabilities]
        is_all ? all_caps : req_caps
      end

      def get_rh_caps_sym(path)
        caps = get_rh_caps(path).map do |c|
          c.downcase.gsub('.', '_').to_sym
        end
        caps.to_a
      end

      ## REG

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

      def get_rh_name_path_list(contr, reg)
        list = get_rh_from_reg(reg).each_with_object([]) do |rh, l|
          rh.message.each do |mh|
            pth = mh.path
            route = recognise_path(pth)
            l << {
              name: rh.resource_name.default_value,
              path: pth,
              route: route,
              full_path: Rails.application.routes.url_for(
                **route,
                host: contr.request.host_with_port
              )
            }
          end
        end
        list.to_a
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

      private :recognise_path
    end
  end
end
