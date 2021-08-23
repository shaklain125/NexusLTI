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
    end
  end
end
