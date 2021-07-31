module LtiUtils
  class << self
    def set_lti_cookie(cookies, key, value)
      cookies[key] = {
        value: value,
        secure: true,
        same_site: :none,
        httponly: true
      }
    end

    def delete_lti_cookie(cookies, key)
      cookies.delete key, {
        secure: true,
        same_site: :none,
        httponly: true
      }
    end
  end
end
