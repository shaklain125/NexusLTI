module LtiUtils
  class LtiRole
    def initialize(params)
      @params = params
    end

    class << self
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

      def valid_student_pages(params, controller_name, action_name)
        contr = [
          :submission
        ].include?(controller_name.to_sym)
        if contr && action_name.to_sym == :new && !_check_token(params)
          valid_aid = params[:aid] == LtiUtils.get_submission_token(params)[:aid]
          return valid_aid
        end
        contr
      end

      def valid_teacher_pages(params, controller_name, action_name)
        controller_name = controller_name.to_sym
        action_name = action_name.to_sym
        valid = true
        config = LtiUtils.get_conf(params)
        aid = config[:aid]
        cid = config[:cid]

        case controller_name
        when :pages
          invalid = [
            :admin_panel,
            :user_list
          ].include?(action_name)
          valid = !invalid
        when :user, :access_token, :marking_tool, :audit_item
          valid = false
        when :course
          invalid = [
            :new,
            :destroy,
            :create,
            :edit,
            :update
            # :index
          ].include?(action_name)
          valid = !invalid
          valid = params[:id] == cid if params[:id] && action_name != :mine && valid
        when :assignment
          valid = params[:cid] == cid if params[:cid] && action_name == :new
          valid = Session.aid_valid?(params[:id], cid) if params[:id] && (action_name != :mine)
        when :deadline_extension
          valid = Session.aid_valid?(params[:aid], cid) if params[:aid] && action_name == :new
        end

        valid
      end

      ## Raise
      def if_student_show_student_pages_raise(params, controller_name, action_name)
        raise LtiLaunch::Error, :invalid_lti_role_access if verify_student(params) && !valid_student_pages(params, controller_name, action_name)
      end

      ## Raise
      def if_teacher_show_teacher_pages_raise(params, controller_name, action_name)
        raise LtiLaunch::Error, :invalid_lti_role_teacher_access if verify_teacher(params) && !valid_teacher_pages(params, controller_name, action_name)
      end

      def valid_student_referer(controller_name, action_name)
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

        page_for_ref
      end

      def valid_teacher_referer(controller_name, action_name)
        controller_name = controller_name.to_sym
        action_name = action_name.to_sym
        false
      end

      private :_check_token, :_get_token
    end

    def as_json
      roles = Roles.roles_json

      sys_roles = Roles.system_roles_json

      custom = LtiUtils.no_prefix_custom(@params)

      role = custom[:membership_role].split(',')

      ctx_role = roles.key(role.first)

      ctx_or_sys = role.length == 1 ? role.first : role.second

      sys_role = sys_roles.key(ctx_or_sys)

      role_inf = { role: { ctx: ctx_role, sys: sys_role }  }

      HashHelper.snake_case_symbolize(role_inf)
    end
  end
end
