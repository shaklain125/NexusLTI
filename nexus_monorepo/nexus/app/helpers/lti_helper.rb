module LtiHelper
  class << self
    def check_lti_tool(id)
      !LtiTool.where(id: id).empty?
    end

    def _get_token_param(params)
      params[:lti_token]
    end

    def contains_token_param(params)
      !params[:lti_token].nil?
    end

    def contains_token_param_raise(params)
      # raise if token missing
      raise LtiLaunch::Unauthorized, :invalid unless contains_token_param(params)
    end

    def raise_if_contains_token(params)
      raise LtiLaunch::Unauthorized, :invalid if contains_token_param(params)
    end

    def get_tool_id(params)
      get_token(params)[:tool_id]
    end

    def get_token(params)
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return {} if token.empty?
      token.symbolize_keys
    end

    def invalid_token(params)
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return true if token.empty?
      false
    end

    def invalid_token_raise(params)
      # raise if it contains token and is invalid
      contains_token = contains_token_param(params)
      invalid = invalid_token(params)
      raise LtiLaunch::Unauthorized, :invalid if contains_token && invalid
      false
    end

    def encrypt_json(plain)
      encrypt(plain.to_json)
    end

    def decrypt_json(cipher)
      return {} if cipher.nil?
      decipher = decrypt(cipher)
      JSON.parse(decipher)
    rescue StandardError => _e
      {}
    end

    def encrypt(str)
      _encrypt(str, '8cb13f93bf4b9bd12846d08c8814755d35fea3ff491bf08a0bbf381fe9a80892703ee58b072c18acc376d72b0d42ad392e42c63309e46e3aff63b450c396520d')
    end

    def decrypt(str)
      _decrypt(str, '8cb13f93bf4b9bd12846d08c8814755d35fea3ff491bf08a0bbf381fe9a80892703ee58b072c18acc376d72b0d42ad392e42c63309e46e3aff63b450c396520d')
    end

    def _encrypt(str, key)
      # OpenSSL::Cipher.ciphers
      cipher = OpenSSL::Cipher.new('CAMELLIA-192-OFB').encrypt
      cipher.key = Digest::SHA1.hexdigest key
      s = cipher.update(str) + cipher.final
      s = s.unpack('H*')
      s.first # .upcase
    end

    def _decrypt(str, key)
      cipher = OpenSSL::Cipher.new('CAMELLIA-192-OFB').decrypt
      cipher.key = Digest::SHA1.hexdigest key
      s = [str].pack("H*").unpack("C*").pack("c*")
      cipher.update(s) + cipher.final
    end

    private :_get_token_param, :_encrypt, :_decrypt
  end

  def parsed_lti_message(request)
    lti_message = IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    lti_message.launch_url = request.url
    lti_message
  end

  def lti_authentication
    @lti_launch = LtiLaunch.check_launch(parsed_lti_message(request))
  end

  def disable_xframe_header
    response.headers.except! 'X-Frame-Options'
  end

  def registration_request
    registration_request = IMS::LTI::Models::Messages::Message.generate(params)
    @registration = LtiRegistration.new(
      registration_request_params: registration_request.post_params,
      tool_proxy_json: LtiToolProxyRegistration.new(registration_request, self).tool_proxy.as_json
    )
    @registration.save!
  end

  def register_proxy(registration)
    LtiToolProxyRegistration.register(registration, self)
  end

  def redirect_to_consumer(registration_result)
    url = registration_result[:return_url]
    url = add_param(url, 'tool_proxy_guid', registration_result[:tool_proxy_uuid])
    url = if registration_result[:status] == 'success'
            add_param(url, 'status', 'success')
          else
            add_param(url, 'status', 'error')
          end
    redirect_to url
  end

  def add_param(url, param_name, param_value)
    uri = URI(url)
    params = URI.decode_www_form(uri.query || '') << [param_name, param_value]
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
