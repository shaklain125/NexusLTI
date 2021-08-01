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
        cookies[:lti_token]
      end
    end

    def set_cookie_token(cookies, session, token_encrypted)
      if session[:session_id] && cookies[:lti_token].nil?
        session[:lti_token] = token_encrypted
      else
        set_lti_cookie(cookies, :lti_token, token_encrypted)
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
      delete_lti_cookie(cookies, :lti_token) if cookie_token_exists(cookies, session)
    end

    def delete_cookie_token_not_session(cookies)
      delete_lti_cookie(cookies, :lti_token) unless cookies[:lti_token].nil?
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

    def from_generator(params)
      !get_token(params)[:generator].nil?
    end

    def from_manage_assignment(params)
      !get_config(params).nil?
    end

    def from_submission(params)
      !get_submission_token(params).nil?
    end

    private :_get_token_param
  end
end
