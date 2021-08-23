module LtiUtils
  class << self
    def _get_token_param(params)
      params[:lti_token]
    end

    def get_token(params)
      _token = _get_token_param(params)
      token = decrypt_json_token(_token)
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

    def update_and_set_token(contr, json)
      params = contr.params
      params[:lti_token] = encrypt_json_token(update_merge_token(params, json))
      set_cookie_token(contr.request.cookies, contr.session, params[:lti_token])
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

    ## Flash

    def flash(contr)
      update_and_set_token(contr, { flash: contr.flash })
    end

    def set_flashes(flash, flash_lti)
      flash_lti.each { |t, m| flash[t] = m }
    end

    private :_get_token_param
  end
end
