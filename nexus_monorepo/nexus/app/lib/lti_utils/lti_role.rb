module LtiUtils
  class << self
    def verify_student(params)
      LtiRole.verify_student(params)
    end

    def verify_teacher(params)
      LtiRole.verify_teacher(params)
    end

    def teacher_can_administrate(params)
      LtiRole.teacher_can_administrate(params)
    end

    def invalidate_devise_non_admin_login(params)
      if params[:user] && params[:user][:email]
        u = User.find_by_email(params[:user][:email])
        is_admin = u && u.admin?
        return u unless is_admin
      end
      nil
    end
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

      def _get_token(params)
        LtiUtils.get_token(params)
      end

      def _check_token(params)
        LtiUtils.invalid_token(params)
      end

      def verify_student(params)
        return false if _check_token(params)
        json = _get_token(params)
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
        json = _get_token(params)
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
        json = _get_token(params)
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
        json = _get_token(params)
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
        raise LtiLaunch::Unauthorized, :invalid unless valid_student_referer(params, request, controller_name, action_name)
        true
      end

      def if_teacher_and_referer_valid_raise(params, request, controller_name, action_name)
        raise LtiLaunch::Unauthorized, :invalid unless valid_teacher_referer(params, request, controller_name, action_name)
        true
      end

      def valid_student_referer(params, request, controller_name, action_name)
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

        is_student_and_valid_page = verify_student(params) && page_for_ref
        is_lms = LtiUtils.check_if_referrer_is_not_lms(request, params)

        return false if is_student_and_valid_page && !is_lms
        true
      end

      def valid_teacher_referer(params, request, controller_name, action_name)
        controller_name = controller_name.to_sym
        action_name = action_name.to_sym
        page_for_ref = false

        is_teacher_and_valid_page = verify_teacher(params) && page_for_ref
        is_lms = LtiUtils.check_if_referrer_is_not_lms(request, params)

        is_teacher_and_valid_page && !is_lms ? false : true
      end

      private :_check_token, :_get_token
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
end
