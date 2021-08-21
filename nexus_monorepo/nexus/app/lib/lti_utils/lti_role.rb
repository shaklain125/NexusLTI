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

      def valid_student_pages(contr)
        params = contr.params
        controller_name = contr.controller_name.to_sym
        action_name = contr.action_name.to_sym
        aid = contr.instance_variable_get('@aid')
        valid_contr = [
          :submission
        ].include?(controller_name)
        return params[:aid] == aid if valid_contr && action_name == :new && !_check_token(params)
        valid_contr
      end

      def valid_teacher_pages(contr)
        params = contr.params
        controller_name = contr.controller_name.to_sym
        action_name = contr.action_name.to_sym
        manage_only_current_cid = contr.instance_variable_get('@manage_only_current_cid')
        manage_only_current_aid = contr.instance_variable_get('@manage_only_current_aid')
        allow_course_delete = contr.instance_variable_get('@allow_course_delete')
        cid = contr.instance_variable_get('@cid')
        valid = true

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
          invalid_actions = [
            :new,
            :create,
            :edit,
            :update,
            :index
          ]
          invalid_actions << :destroy unless allow_course_delete
          invalid_actions << :mine if manage_only_current_cid
          invalid_actions << :show if manage_only_current_aid && !manage_only_current_cid
          invalid = invalid_actions.include?(action_name)
          valid = !invalid
          valid = Session.my_cid?(params[:id], params) if params[:id] && action_name != :mine && valid
        when :assignment
          if params[:cid] && action_name == :new
            valid = if manage_only_current_aid && !manage_only_current_cid
                      params[:cid].to_s == cid
                    else
                      Session.my_cid?(params[:cid], params)
                    end
          end
          valid = Session.my_aid?(params[:id], params) if params[:id] && action_name != :mine
        when :deadline_extension
          valid = Session.my_aid?(params[:aid], params) if params[:aid] && action_name == :new
          valid = Session.my_dex_id?(params[:id], params) if params[:id] && action_name != :create
          valid = Session.my_aid?(params[:deadline_extension][:assignment_id], params) if params[:deadline_extension] && action_name == :create
        end

        valid
      end

      ## Raise
      def if_student_show_student_pages_raise(contr)
        raise LtiLaunch::Error, :invalid_lti_role_access if verify_student(contr.params) && !valid_student_pages(contr)
      end

      ## Raise
      def if_teacher_show_teacher_pages_raise(contr)
        raise LtiLaunch::Error, :invalid_lti_role_teacher_access if verify_teacher(contr.params) && !valid_teacher_pages(contr)
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
