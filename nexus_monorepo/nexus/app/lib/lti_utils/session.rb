module LtiUtils
  class Session
    class << self
      def https_session_enabled
        LTI_HTTPS_SESSION
      end

      def http_session_enabled
        LTI_HTTP_SESSION
      end

      def create_teacher(email, name)
        u = User.find_by_email(email)
        u ||= User.create(email: email,
                          password: '12345678',
                          password_confirmation: '12345678',
                          name: name,
                          admin: true)
        u
      end

      def create_student(email, name)
        u = User.find_by_email(email)
        u ||= User.create(email: email,
                          password: '12345678',
                          password_confirmation: '12345678',
                          name: name)
        u
      end

      def create_session(user, params)
        return nil unless user
        session_exists = LtiSession.where({ user: user.id })
        session_exists.delete_all if session_exists.any?
        LtiSession.create(lti_tool: LtiTool.find(LtiUtils.get_tool_id(params)), user: user)
      end

      def get_current_user(params)
        uid = LtiUtils.get_user_id(params)
        return nil if LtiUtils::LtiRole.verify_teacher(params) && !uid
        lti_session = LtiSession.where({ lti_tool: LtiUtils.get_tool_id(params), user: uid })
        return nil unless lti_session.any?
        lti_session.first.user
      end

      def logout_session(params, cookies, session)
        lti_session = LtiSession.find_by_lti_tool_id(LtiUtils.get_tool_id(params))
        lti_session.delete if lti_session
        LtiUtils.update_and_set_token(params, cookies, session, LtiUtils.update_user_id(params, nil))
      end

      def https_session?(request)
        is_https = request.ssl?
        https_session_enabled && is_https
      end

      def http_session?(request)
        is_https = request.ssl?
        http_session_enabled && !is_https
      end

      ## Raise
      def raise_if_invalid_session(cookies, session, request, params)
        id = session[:session_id]
        session_token = session[:lti_token]
        cookies_token = LtiUtils.get_cookie_token_only(cookies)

        is_https_session_valid = id && !session_token.nil? && cookies_token.nil?
        is_http_session_valid = ((id && session_token.nil?) || !id) && !cookies_token.nil?

        https_valid = (https_session?(request) && is_https_session_valid)
        http_valid = (http_session?(request) && is_http_session_valid)

        is_valid_session = (https_valid || http_valid)

        LtiUtils.delete_cookie_token_not_session(cookies) if !http_valid || https_valid

        raise LtiLaunch::Error, :invalid_lti_session if LtiUtils.contains_token_param(params) && !is_valid_session
      end

      def invalidate_devise_non_admin_login(params)
        return nil unless LTI_DISABLE_DEVISE_NON_ADMIN_LOGIN
        if params[:user] && params[:user][:email]
          u = User.find_by_email(params[:user][:email])
          is_admin = u && u.admin?
          return u unless is_admin
        end
        nil
      end
    end
  end
end
