module LtiHelper
  class HashHelper
    def self.snake_case(value)
      value = value.to_h
      value = value.map { |k, v| [k.to_s.underscore.to_sym, v.is_a?(Hash) ? snake_case(v) : v] }
      value.to_h
    end

    def self.snake_case_symbolize(value)
      snake_case(value).symbolize_keys
    end
  end

  class CryptoTool
    def initialize(secret)
      @secret = secret
    end

    def encrypt_json(plain)
      encrypt(plain.to_json)
    end

    def decrypt_json(cipher)
      return {} if cipher.nil?
      decipher = decrypt(cipher)
      json = JSON.parse(decipher)
      HashHelper.snake_case_symbolize(json)
    rescue StandardError => _e
      {}
    end

    def encrypt(str)
      _encrypt(str, @secret)
    end

    def decrypt(str)
      _decrypt(str, @secret)
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

    private :_encrypt, :_decrypt
  end

  class LtiRole
    def initialize(params)
      @params = params
    end

    class << self
      def roles_json
        roles = IMS::LIS::Roles::Context::Handles
        constants = roles.constants.map { |c| [c, roles.const_get(c)]  }
        HashHelper.snake_case_symbolize(constants)
      end

      def system_roles_json
        roles = {
          SysAdmin: 'http://purl.imsglobal.org/vocab/lis/v2/person#SysAdmin',
          SysSupport: 'http://purl.imsglobal.org/vocab/lis/v2/person#SysSupport',
          Creator: 'http://purl.imsglobal.org/vocab/lis/v2/person#Creator',
          AccountAdmin: 'http://purl.imsglobal.org/vocab/lis/v2/person#AccountAdmin',
          User: 'http://purl.imsglobal.org/vocab/lis/v2/person#User',
          Administrator: 'http://purl.imsglobal.org/vocab/lis/v2/person#Administrator',
          None: 'http://purl.imsglobal.org/vocab/lis/v2/person#None'
        }
        roles = roles.map { |k, v| [k.to_s.underscore.to_sym, v] }
        HashHelper.snake_case_symbolize(roles)
      end

      def _check_token(params)
        LtiHelper.invalid_token(params)
      end

      def verify_student(params)
        return false if _check_token(params)
        json = LtiHelper.get_token(params)
        [
          :learner,
          :learner_learner,
          :learner_non_credit_learner,
          :learner_guest_learner,
          :learner_external_learner,
          :learner_instructor
        ].include?(json[:role][:ctx].to_sym)
      end

      def verify_teacher(params)
        return false if _check_token(params)
        json = LtiHelper.get_token(params)
        [
          :instructor,
          :instructor_primary_instructor,
          :instructor_lecturer,
          :instructor_guest_instructor,
          :instructor_external_instructor
        ].include?(json[:role][:ctx].to_sym)
      end

      def verify_admin(params)
        return false if _check_token(params)
        json = LtiHelper.get_token(params)
        [
          :administrator,
          :administrator_administrator,
          :administrator_support,
          :administrator_developer,
          :administrator_system_administrator,
          :administrator_external_system_administrator,
          :administrator_external_developer,
          :administrator_external_support
        ].include?(json[:role][:ctx].to_sym)
      end

      def verify_sys_admin(params)
        return false if _check_token(params)
        json = LtiHelper.get_token(params)
        can_admin = json[:role][:sys]
        unless can_admin.nil?
          can_admin = [
            :sys_admin,
            :creator,
            :account_admin,
            :administrator
          ].include?(can_admin.to_sym)
        end
        can_admin
      end

      def teacher_can_administrate(params)
        verify_teacher(params) && verify_sys_admin(params)
      end

      def if_student_show_student_pages_raise(params, controller_name)
        conrollers_for_students = [
          :submission
        ].include?(controller_name.to_sym)
        raise LtiLaunch::Unauthorized, :invalid if verify_student(params) && !conrollers_for_students
      end

      def if_student_and_referer_valid_raise(params, request, controller_name, action_name)
        controller_name = controller_name.to_sym
        action_name = action_name.to_sym
        page_for_ref = false

        case controller_name
        when :submission
          action_valid = [
            :new
          ].include?(action_name)
          page_for_ref = action_valid
        else
          page_for_ref = false
        end

        LtiHelper.raise_if_referrer_is_not_lms(request, params) if verify_student(params) && page_for_ref
      end

      private :_check_token
    end

    def no_prefix_custom(params)
      prefix = 'custom_'
      params = params.map { |k, v| [k.starts_with?(prefix) ? k[prefix.length, k.length - 1] : k, v] }
      HashHelper.snake_case_symbolize(params)
    end

    def as_json
      roles = self.class.roles_json

      sys_roles = self.class.system_roles_json

      custom = no_prefix_custom(@params)

      role = custom[:membership_role].split(',')

      ctx_role = roles.key(role.first)

      ctx_or_sys = role.length == 1 ? role.first : role.second

      sys_role = sys_roles.key(ctx_or_sys)

      role_inf = { role: { ctx: ctx_role, sys: sys_role }  }

      HashHelper.snake_case_symbolize(role_inf)
    end

    private :no_prefix_custom
  end

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

    def raise_if_null_referrer_and_lti(request, params)
      referrer = request.referrer
      raise LtiLaunch::Unauthorized, :invalid if !referrer && contains_token_param(params)
    end

    def raise_if_session_and_lti(session, params)
      id = session[:session_id]
      raise LtiLaunch::Unauthorized, :invalid if id && contains_token_param(params)
    end

    def raise_if_referrer_is_not_lms(request, params)
      referrer = request.referrer
      valid_referrers = [
        '192.168.1.81'
      ]
      valid = valid_referrers.include?(URI.parse(referrer).host)
      raise LtiLaunch::Unauthorized, :invalid if !valid && contains_token_param(params)
    end

    def get_tool_id(params)
      get_token(params)[:tool_id]
    end

    def get_user_id(params)
      get_token(params)[:user_id]
    end

    def get_token(params)
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return {} if token.empty?
      token
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

    def secret
      '8cb13f93bf4b9bd12846d08c8814755d35fea3ff491bf08a0bbf381fe9a80892703ee58b072c18acc376d72b0d42ad392e42c63309e46e3aff63b450c396520d'
    end

    def encrypt_json(str)
      CryptoTool.new(secret).encrypt_json(str)
    end

    def decrypt_json(str)
      CryptoTool.new(secret).decrypt_json(str)
    end

    def verify_student(params)
      LtiRole.verify_student(params)
    end

    def verify_teacher(params)
      LtiRole.verify_teacher(params)
    end

    def teacher_can_administrate(params)
      LtiRole.teacher_can_administrate(params)
    end

    private :_get_token_param, :secret
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
