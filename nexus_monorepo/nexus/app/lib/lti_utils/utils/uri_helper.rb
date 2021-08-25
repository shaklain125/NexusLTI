module LtiUtils
  class URIHelper
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
          URI.parse(uri).host
        rescue StandardError
          nil
        end
      end

      def get_domain(uri)
        return nil unless uri
        begin
          URI.join(uri, "/").to_s
        rescue StandardError
          nil
        end
      end

      def http_get_body_empty?(uri)
        Faraday.new.get(uri).body.empty?
      rescue StandardError
        true
      end

      def domanin_exists?(uri)
        !http_get_body_empty?(get_domain(uri))
      end
    end
  end
end
