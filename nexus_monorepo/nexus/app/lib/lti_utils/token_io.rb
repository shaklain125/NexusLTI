module LtiUtils
  class << self
    def _get_token_param(params)
      params[:lti_token]
    end

    def get_token(params)
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return {} if token.empty?
      token
    end

    def get_cookie_token(cookies, session)
      if session[:session_id] && cookies[:lti_token].nil?
        session[:lti_token]
      else
        get_cookie_token_only(cookies)
      end
    end

    def get_cookie_token_only(cookies)
      LtiUtils::Session.http_cookie_enabled? ? cookies[:lti_token] : nil
    end

    def set_cookie_token(cookies, session, token_encrypted)
      if session[:session_id] && cookies[:lti_token].nil?
        session[:lti_token] = token_encrypted
      else
        CookieHelper.set_lti_cookie(cookies, :lti_token, token_encrypted)
      end
    end

    def update_user_id(params, id)
      get_token(params).merge({ user_id: id })
    end

    def update_merge_token(params, json)
      get_token(params).merge(json)
    end

    def update_and_set_token(params, cookies, session, json)
      params[:lti_token] = encrypt_json(update_merge_token(params, json))
      set_cookie_token(cookies, session, params[:lti_token])
    end

    def delete_cookie_token(cookies, session)
      delete_cookie_token_session(session)
      delete_cookie_token_not_session(cookies)
    end

    def delete_cookie_token_session(session)
      session.delete(:lti_token) unless session[:lti_token].nil?
    end

    def delete_cookie_token_not_session(cookies)
      CookieHelper.delete_lti_cookie(cookies, :lti_token) unless cookies[:lti_token].nil?
    end

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
      get_token(params)[:config]
    end

    def get_submission_token(params)
      get_token(params)[:submission]
    end

    def from_generator?(params)
      !get_token(params)[:generator].nil?
    end

    def from_manage_assignment?(params)
      !get_config(params).nil?
    end

    def from_submission?(params)
      !get_submission_token(params).nil?
    end

    def get_flashes(params)
      get_token(params)[:flash] || []
    end

    def get_flashes!(params, cookies, session)
      flashes = get_flashes(params)
      update_and_set_token(params, cookies, session, { flash: [] })
      flashes
    end

    def flash(flash, params, cookies, session)
      update_and_set_token(params, cookies, session, { flash: flash })
    end

    def set_flashes(flash, flash_lti)
      flash_lti.each { |t, m| flash[t] = m }
    end

    private :_get_token_param
  end
end
