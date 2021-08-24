module LtiUtils
  class Session
    class << self
      ## Http and Https checks

      def https_session_enabled?
        LTI_HTTPS_SESSION
      end

      def http_session_enabled?
        LTI_HTTP_SESSION
      end

      def http_cookie_enabled?
        return false if LTI_HTTPS_SESSION
        return LTI_ENABLE_COOKIE_TOKEN_WHEN_HTTP if LTI_HTTP_SESSION
      end

      def https_session?(request)
        is_https = request.ssl?
        https_session_enabled? && is_https
      end

      def http_session?(request)
        is_https = request.ssl?
        http_session_enabled? && !is_https
      end

      ## Create and update users. Create session and course

      def update_user_details(u, name)
        return nil unless u
        pw = Devise.friendly_token(32)
        u.name = name
        u.password = pw
        u.password_confirmation = pw
        u.save!
        u
      end

      def create_user!(email, name, admin: false)
        u = User.find_by_email(email)
        unless u
          u = User.new
          u.email = email
          u.admin = admin
        end
        update_user_details(u, name)
      end

      def create_teacher(email, name)
        create_user!(email, name, admin: true)
      end

      def create_student(email, name)
        create_user!(email, name)
      end

      def create_course(user, is_teacher, source_id:, title:, description:)
        found_course = LtiCourse.where({ source: source_id })
        if found_course.any?

          found_course = found_course.first.course

          found_course.title = title
          found_course.description = description
          found_course.save!

          if found_course && is_teacher
            teacher_found_in_course = found_course.teachers.include?(user)

            if !teacher_found_in_course && !user.my_courses.include?(found_course)
              found_course.teachers << user
              found_course.save!
              user.courses << found_course
              user.save!
            end
          end

          return found_course
        end

        return nil unless is_teacher

        lti_course = LtiCourse.new(source: source_id)

        course = Course.new(title: title, description: description)
        course.teachers << user
        course.save!

        user.courses << course
        user.save!

        lti_course.course = course
        lti_course.save!

        course
      end

      def create_session(user, params)
        return nil unless user
        session_exists = LtiSession.where({ user: user.id })
        session_exists.delete_all if session_exists.any?
        tool = LtiTool.find(LtiUtils::Token.get_tool_id(params))
        return nil unless tool
        lti_session = LtiSession.new(lti_tool: tool, user: user)
        lti_session.save!
        lti_session
      end

      ## Get current user from lti session

      def get_current_user(params)
        uid = LtiUtils::Token.get_user_id(params)
        lti_session = LtiSession.where({ lti_tool: LtiUtils::Token.get_tool_id(params), user: uid }) if uid
        return nil unless (!lti_session || lti_session.any?) && lti_session && uid
        lti_session.first.user
      end

      ## Logout session. Used for lti exit

      def logout_session(contr)
        params = contr.params
        lti_session = LtiSession.find_by_lti_tool_id(LtiUtils::Token.get_tool_id(params))
        lti_session.delete if lti_session
        LtiUtils::Token.update_and_set_token(contr, LtiUtils::Token.update_user_id(params, nil))
      end

      ## Storing flash in lti token when http

      def http_flash(contr)
        # Set lti flashes (inside lti_token) if it's http_session as flashes will not work without session
        # Session flashes works in renders but not redirect_to
        session_nil = contr.session[:session_id].nil?
        is_http_session = http_session?(contr.request) && session_nil
        lti_http_flash = LtiUtils::Token.exists_and_valid?(contr.params) && is_http_session && !contr.flash.empty?
        LtiUtils::Token.flash(contr) if lti_http_flash
      end

      ## Permissions

      def manage_only_current_cid?
        LTI_TEACHER_MANAGE_ONLY_CURRENT_COURSE
      end

      def manage_only_current_aid?
        LTI_TEACHER_MANAGE_ONLY_CURRENT_ASSIGNMENT
      end

      def allow_course_delete?
        LTI_TEACHER_ALLOW_COURSE_DELETE
      end

      def allow_only_first_teacher_cid_delete?
        LTI_ALLOW_ONLY_FIRST_TEACHER_COURSE_DELETE
      end

      def allow_only_first_teacher_create_aid?
        LTI_ALLOW_ONLY_FIRST_TEACHER_CREATE_ASSIGNMENT
      end

      def allow_only_first_teacher_edit_aid?
        LTI_ALLOW_ONLY_FIRST_TEACHER_EDIT_ASSIGNMENT
      end

      def allow_only_first_teacher_delete_aid?
        LTI_ALLOW_ONLY_FIRST_TEACHER_DELETE_ASSIGNMENT
      end

      ## First teacher only?

      def first_teacher?(contr)
        u = get_user(contr.params)
        c = contr.instance_variable_get('@cid_course') if u
        t = c.teachers.first if c
        t.nil? ? false : t.id == u.id
      end

      def invalidate_cid_del_if_not_first_teacher?(contr)
        first_teacher?(contr) || !allow_only_first_teacher_cid_delete?
      end

      def invalidate_aid_c_if_not_first_teacher?(contr)
        first_teacher?(contr) || !allow_only_first_teacher_create_aid?
      end

      def invalidate_aid_u_d_if_not_first_teacher?(contr)
        valid = first_teacher?(contr)
        case contr.action_name.to_sym
        when :edit, :update
          valid ||= !allow_only_first_teacher_edit_aid?
        when :destroy
          valid ||= !allow_only_first_teacher_delete_aid?
        else
          valid ||= true
        end
        valid
      end

      ## aid and cid checking

      def my_aid_from_my_cid?(aid, params)
        return false unless aid
        a = Assignment.find(aid.to_i)
        return false unless a
        my_cid?(a.course.id, params)
      rescue StandardError
        false
      end

      def my_cid?(cid, params)
        return false unless cid
        c = Course.find(cid.to_i)
        return false unless c
        get_user(params).my_courses.include?(c)
      rescue StandardError
        false
      end

      def my_dex_id_from_my_aid?(dex_id, params)
        return false unless dex_id
        d = DeadlineExtension.find(dex_id.to_i)
        return false unless d
        my_aid?(d.assignment.id, params)
      rescue StandardError
        false
      end

      ## Get Assignment from aid and cid

      def validate_assignment(aid, cid)
        return [nil, false] if aid.nil? || cid.nil? || !aid || !cid
        aid_find = Assignment.where({ id: aid, course: cid }) unless aid.nil?
        aid_valid = aid.nil? ? false : aid_find.any?
        aid_a = aid_find.first unless aid.nil?
        [aid_a, aid_valid]
      rescue StandardError
        [nil, false]
      end

      ## Extract course id from url

      def get_course_id_from_pres_url(pres_url)
        uri = URI(pres_url)
        query = URI.decode_www_form(uri.query || '')
        uri.query = URI.encode_www_form(query)
        query = query.to_h
        course_id = query['course'].to_s.strip
        course_id.empty? ? nil : course_id
      rescue StandardError
        nil
      end

      ## Get obj from conf ids

      def get_user(params)
        uid = LtiUtils::Token.get_user_id(params)
        return nil unless uid
        User.find(uid)
      rescue StandardError
        nil
      end

      def get_course(params)
        cid = LtiUtils::Token.get_conf(params)[:cid]
        return nil unless cid
        Course.find(cid)
      rescue StandardError
        nil
      end

      ## Raise 2

      def raise_if_invalid_session(contr)
        request = contr.request
        cookies = request.cookies
        session = contr.session
        params = contr.params
        id = session[:session_id]
        session_token = session[:lti_token]
        cookies_token = LtiUtils::Token.get_cookie_only(cookies)

        is_https_session_valid = id && !session_token.nil? && cookies_token.nil?
        is_http_session_valid = ((id && session_token.nil?) || !id) && !cookies_token.nil?

        https_valid = (https_session?(request) && is_https_session_valid)
        http_valid = (http_session?(request) && is_http_session_valid)

        is_valid_session = (https_valid || http_valid)

        LtiUtils::Token.delete_cookie_only(cookies) if !http_valid || https_valid

        raise LtiLaunch::Error, :invalid_lti_session if LtiUtils::Token.exists?(params) && !is_valid_session
      end

      def raise_if_course_not_found(course)
        raise LtiLaunch::Error, :course_not_found unless course
      end
    end
  end
end
