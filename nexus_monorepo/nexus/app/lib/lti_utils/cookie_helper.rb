module LtiUtils
  class CookieHelper
    class << self
      def set_lti_cookie(cookies, key, value)
        return unless LTI_ENABLE_COOKIE_TOKEN_WHEN_HTTP
        cookies[key] = {
          value: value,
          secure: true,
          same_site: :none,
          httponly: true
        }
      end

      def delete_lti_cookie(cookies, key)
        return unless LTI_ENABLE_COOKIE_TOKEN_WHEN_HTTP
        cookies.delete key, {
          secure: true,
          same_site: :none,
          httponly: true
        }
      end
    end
  end
end
