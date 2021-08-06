module LtiUtils
  class << self
    def raise_if_null_referrer_and_lti(request, params)
      referrer = request.referrer
      raise LtiLaunch::Unauthorized, :invalid_origin if !referrer && contains_token_param(params)
    end

    def lms_hosts
      LTI_VALID_LMS_ORIGIN_HOSTS
    end

    def check_if_is_lms_origin(request)
      referrer = request.referrer
      origin = request.headers['origin']
      return false if !referrer || !origin
      valid_referrers = lms_hosts
      return false unless valid_referrers.any?
      referer_valid = check_host(referrer, valid_referrers)
      origin_valid = check_host(origin, valid_referrers)
      referer_valid && origin_valid
    end

    def check_if_is_lms_referrer(request)
      referrer = request.referrer
      return false unless referrer
      valid_referrers = lms_hosts
      return false unless valid_referrers.any?
      check_host(referrer, valid_referrers)
    end

    def raise_if_invalid_token_ip(request, params)
      ip = get_token_ip(params)
      not_nil = request.remote_ip && ip
      raise LtiLaunch::Unauthorized, :invalid_origin if ((not_nil && (request.remote_ip != ip)) || !not_nil) && contains_token_param(params)
    end
  end
end
