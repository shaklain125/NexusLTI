class LtiController < ApplicationController
  include LtiHelper

  before_action :check_if_signed_in, except: [:launch, :login, :login_post]
  before_action :contains_token_param, except: [:launch]
  before_action :check_launch, only: [:launch]
  skip_before_action :verify_authenticity_token, only: [:launch]

  def check_if_signed_in
    raise LtiLaunch::Error, :missing_lti_session unless user_signed_in?
  end

  def check_launch
    @lti_launch = LtiLaunch.check_launch(LtiUtils.models.parsed_lti_message(request))
  end

  def contains_token_param
    LtiUtils.contains_token_param_raise(params)
  end

  def launch
    @message = (@lti_launch && @lti_launch.message) || LtiUtils.models.generate_message(request.request_parameters)
    @launch_id = @lti_launch.id
    @tool_id = @lti_launch.lti_tool_id

    custom_params = @message.custom_params
    custom = LtiUtils.no_prefix_custom(custom_params)
    custom_params_exists = LtiUtils.keys_in_custom?(
      custom,
      LtiUtils.required_custom_params
    )
    raise LtiLaunch::Error, :missing_arguments unless custom_params_exists

    config = custom[:lti_config]
    config = LtiUtils.decrypt_json(config)
    person = { email: custom[:person_email_primary], name: custom[:person_name_full] }

    token_data = {
      tool_id: @tool_id,
      role: LtiUtils::LtiRole.new(custom_params).as_json[:role],
      ip_addr: request.remote_ip
    }

    params[:lti_token] = LtiUtils.encrypt_json(token_data)

    is_student = LtiUtils::LtiRole.verify_student(params)
    is_teacher = LtiUtils::LtiRole.verify_teacher(params)

    user = LtiUtils::Session.create_student(person[:email], person[:name]) if is_student # create_student('student2@student.com', 'Student2')

    user = User.find_by_email(config[:email]) if is_teacher # || 'teacher@teacher.com' person[:email] -- create_teacher(person[:email], person[:name])

    LtiUtils::Session.create_session(user, params)  if is_student || is_teacher

    LtiUtils.update_and_set_token(params, cookies, session, LtiUtils.update_user_id(params, user.nil? ? nil : user.id))

    a_params_nil = config[:aid].nil? || config[:cid].nil?
    aid_find = Assignment.where({ id: config[:aid], course: config[:cid] }) unless a_params_nil
    aid_valid = a_params_nil ? false : aid_find.any?
    aid_a = aid_find.first unless a_params_nil

    if is_student
      if aid_valid
        if aid_a.started?
          LtiUtils.update_and_set_token(params, cookies, session, { submission: { aid: config[:aid] } })
          redirect_to new_submission_path(aid: config[:aid])
        else
          raise LtiLaunch::Error, :assigment_not_started
        end
      else
        raise LtiLaunch::Error, :invalid_aid
      end
      return
    elsif is_teacher
      if aid_valid
        LtiUtils.update_and_set_token(params, cookies, session, { config: { aid: config[:aid], cid: config[:cid] } })
        redirect_to action: :manage_assignment
      else
        LtiUtils.update_and_set_token(params, cookies, session, { generator: true })
        redirect_to action: :login
      end
      return
    end

    redirect_to action: :exit
  end

  def login
    redirect_to action: :configure if current_user
  end

  def login_post
    u = User.find_by_email(params[:user][:email])
    valid_user = u.valid_password?(params[:user][:password])
    is_admin = u && u.admin?

    invalid_login = !valid_user || LtiUtils.invalid_token(params) || !@is_teacher || !is_admin

    if invalid_login
      redirect_to action: :login
      return
    end

    LtiUtils::Session.create_session(u, params)

    LtiUtils.update_and_set_token(params, cookies, session, LtiUtils.update_user_id(params, u.id))

    if LtiUtils.from_generator(params)
      redirect_to action: :configure
      return
    end

    redirect_to action: :exit
  end

  def logout
    unless LtiUtils.invalid_token(params)
      LtiUtils::Session.logout_session(params, cookies, session)
      LtiUtils.update_and_set_token(params, cookies, session, { generator: true, config: nil })
    end

    if @is_teacher
      redirect_to action: :login
      return
    end

    redirect_to action: :exit
  end

  def exit
    exit_lti

    if @is_teacher
      redirect_to new_user_session_path
      return
    end

    redirect_to root_path
  end

  def configure
    redirect_to action: :login unless current_user
  end

  def configure_generate
    aid = params[:assignment]
    assignment = Assignment.find(aid)
    cid = assignment.course.id unless assignment.nil?
    u = current_user
    render json: { config: u.nil? || cid.nil? || !u ? 'Error' : LtiUtils.encrypt_json({ aid: aid, cid: cid, email: u.email }) }
  rescue StandardError
    render json: { config: 'Error' }
  end

  def manage_assignment
    config = LtiUtils.get_config(params)
    a_exists = Assignment.where({ id: config[:aid], course: config[:cid] })
    unless a_exists.any?
      LtiUtils.update_and_set_token(params, cookies, session, { generator: true, config: nil, user_id: nil })
      redirect_to action: :login
      return
    end
    @assignment = a_exists.first
    @course = Course.find(config[:cid])
  end
end
