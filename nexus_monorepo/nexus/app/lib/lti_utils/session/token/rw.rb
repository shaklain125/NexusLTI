module LtiUtils
  module Token
    class << self
      ## Get

      def get_token_param(params)
        params[:lti_token]
      end

      def get_token(params)
        token = decrypt(get_token_param(params))
        return {} if token.empty?
        token
      end

      def get_cookie_token(cookies, session)
        if session[:session_id] && cookies[:lti_token].nil?
          session[:lti_token]
        else
          get_cookie_only(cookies)
        end
      end

      def get_cookie_only(cookies)
        Session.http_cookie_enabled? ? cookies[:lti_token] : nil
      end

      def set_cookie_token(cookies, session, token_encrypted)
        if session[:session_id] && cookies[:lti_token].nil?
          session[:lti_token] = token_encrypted
        else
          CookieHelper.set_lti_cookie(cookies, :lti_token, token_encrypted)
        end
      end

      ## Encryption

      def token_secret
        Setup.config.token_secret
      end

      def encrypt(token_data)
        LtiUtils.encrypt_json(token_data, key: token_secret)
      end

      def decrypt(token_data)
        LtiUtils.decrypt_json(token_data, key: token_secret)
      end

      ## Update

      def update_user_id(params, id)
        get_token(params).merge({ user_id: id })
      end

      def update_merge_token(params, json)
        get_token(params).merge(json)
      end

      def update_and_set_token(contr, json)
        params = contr.params
        params[:lti_token] = encrypt(update_merge_token(params, json))
        set_cookie_token(contr.request.cookies, contr.session, params[:lti_token])
      end

      ## Delete

      def delete_cookie_token(cookies, session)
        delete_cookie_session_only(session)
        delete_cookie_only(cookies)
      end

      def delete_cookie_session_only(session)
        session.delete(:lti_token) unless session[:lti_token].nil?
      end

      def delete_cookie_only(cookies)
        CookieHelper.delete_lti_cookie(cookies, :lti_token) unless cookies[:lti_token].nil?
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

      def flash(contr)
        update_and_set_token(contr, { flash: contr.flash })
      end

      def set_flashes(flash, flash_lti)
        flash_lti.each { |t, m| flash[t] = m }
      end

      private :get_token_param, :get_token, :token_secret
    end
  end
end
