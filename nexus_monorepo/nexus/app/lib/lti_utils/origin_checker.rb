module LtiUtils
  class << self
    def raise_if_null_referrer_and_lti(request, params)
      referrer = request.referrer
      raise LtiLaunch::Unauthorized, :invalid if !referrer && contains_token_param(params)
    end

    def raise_if_referrer_is_not_lms(request, params)
      raise LtiLaunch::Unauthorized, :invalid if check_if_referrer_is_not_lms(request, params)
    end

    def check_if_referrer_is_not_lms(request, params)
      referrer = request.referrer
      origin = request.headers['origin']
      return false if !referrer || !origin
      valid_referrers = [
        '192.168.1.81'
      ]
      referer_valid = check_host(referrer, valid_referrers)
      origin_valid = check_host(origin, valid_referrers)
      valid = referer_valid && origin_valid
      return false if !valid && contains_token_param(params)
      true
    end

    def raise_if_invalid_token_ip(request, params)
      ip = get_token_ip(params)
      not_nil = request.remote_ip && ip
      raise LtiLaunch::Unauthorized, :invalid if ((not_nil && (request.remote_ip != ip)) || !not_nil) && contains_token_param(params)
    end
  end
end
