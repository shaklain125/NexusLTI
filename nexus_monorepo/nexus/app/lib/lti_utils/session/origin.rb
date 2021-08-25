module LtiUtils
  class Origin
    class << self
      def lms_hosts
        Setup.config.lms_hosts
      end

      def lms_origin?(request)
        referrer = request.referrer
        origin = request.headers['origin']
        return false if !referrer || !origin
        valid_referrers = lms_hosts
        return false unless valid_referrers.any?
        referer_valid = URIHelper.check_host(referrer, valid_referrers)
        origin_valid = URIHelper.check_host(origin, valid_referrers)
        referer_valid && origin_valid
      end

      def same_origin?(request)
        ref = request.referrer
        http_referer_uri = URIHelper.http_referer_uri(request)
        origin = request.headers['origin']
        origin_host = URIHelper.get_host(origin)
        host = request.host

        same_ohost_and_referrer = URIHelper.check_host(ref, [origin_host])

        same_host_and_referrer = URIHelper.check_host(ref, [host])

        same_host_and_referrer = if origin.nil? && host.nil?
                                   false
                                 elsif host.nil?
                                   same_ohost_and_referrer
                                 else
                                   same_ohost_and_referrer || same_host_and_referrer
                                 end

        http_referer_and_host = http_referer_uri ? host == http_referer_uri.host : false

        same_host_and_referrer && http_referer_and_host
      end

      def disable_xframe_header(response)
        # response.headers.delete "X-Frame-Options"
        response.headers.except!('X-Frame-Options')
      end

      ## Raise 2

      def raise_if_invalid_token_ip(contr)
        params = contr.params
        r_ip = contr.request.remote_ip
        ip = LtiUtils::Token.get_ip(params)
        not_nil = r_ip && ip
        raise LtiLaunch::Error, :invalid_origin if ((not_nil && (r_ip != ip)) || !not_nil) && LtiUtils::Token.exists?(params)
      end

      def raise_if_null_referrer_and_lti(contr)
        referrer = contr.request.referrer
        params = contr.params
        raise LtiLaunch::Error, :invalid_origin if !referrer && LtiUtils::Token.exists?(params)
      end
    end
  end
end
