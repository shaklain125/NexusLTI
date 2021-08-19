module LtiUtils
  class CookieHelper
    class << self
      def set_lti_cookie(cookies, key, value)
        return unless LtiUtils::Session.http_cookie_enabled?
        cookies[key] = {
          value: value,
          secure: true,
          same_site: :none,
          httponly: true
        }
      end

      def delete_lti_cookie(cookies, key)
        return unless LtiUtils::Session.http_cookie_enabled?
        cookies.delete key, {
          secure: true,
          same_site: :none,
          httponly: true
        }
      end
    end
  end
end
