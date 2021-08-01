module LtiUtils
  class << self
    def http_referer_uri(request)
      request.env["HTTP_REFERER"] && URI.parse(request.env["HTTP_REFERER"])
    end

    def check_host(url, hostnames)
      hostnames.include?(get_host(url))
    end

    def get_host(uri)
      return nil unless uri
      begin
        Uri.parse(uri).host
      rescue StandardError
        nil
      end
    end

    def add_param(url, param_name, param_value)
      uri = URI(url)
      params = URI.decode_www_form(uri.query || '') << [param_name, param_value]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def check_if_mobile_user_agent(request)
      mobile = request.user_agent =~ /Mobile|webOS/
      !mobile.nil?
    end
  end
end
