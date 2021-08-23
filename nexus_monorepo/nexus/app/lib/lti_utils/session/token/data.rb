module LtiUtils
  class << self
    def get_tool_id(params)
      get_token(params)[:tool_id]
    end

    def get_user_id(params)
      get_token(params)[:user_id]
    end

    def get_token_ip(params)
      get_token(params)[:ip_addr]
    end

    def get_config(params)
      get_token(params)[:config] || {}
    end

    def get_gen(params)
      get_token(params)[:generator] || {}
    end

    def get_submission_token(params)
      get_token(params)[:submission] || {}
    end

    def from_generator?(params, controller_name: nil, action_name: nil)
      from = !get_gen(params).empty?
      return from if controller_name.nil? || action_name.nil?
      from_path = controller_name.to_sym == :lti && action_name.to_sym == :configure
      from && !from_path
    end

    def from_manage_assignment?(params, controller_name: nil, action_name: nil)
      from = !get_config(params).empty?
      return from if controller_name.nil? || action_name.nil?
      from_path = controller_name.to_sym == :lti && action_name.to_sym == :manage_assignment
      from && !from_path
    end

    def from_submission?(params, controller_name: nil, action_name: nil)
      from = !get_submission_token(params).empty?
      return from if controller_name.nil? || action_name.nil?
      from_path = controller_name.to_sym == :submission && action_name.to_sym == :new
      from && !from_path
    end

    def gen_data_update(params)
      { generator: { cid: get_config(params)[:cid] }, config: nil }
    end

    def get_conf(params, *attrs)
      d = {}
      if from_generator?(params)
        d = get_gen(params)
      elsif from_manage_assignment?(params)
        d = get_config(params)
      elsif from_submission?(params)
        d = get_submission_token(params)
      end
      return d.values_at(*attrs) unless attrs.empty?
      d
    end

    ## Flash

    def get_flashes(params)
      get_token(params)[:flash] || []
    end

    def get_flashes!(contr)
      flashes = get_flashes(contr.params)
      update_and_set_token(contr, { flash: [] })
      flashes
    end
  end
end
