require 'ims/lti'
require 'ims/lis'
class LtiController < ApplicationController
  include LtiHelper

  before_action :contains_token_param, except: [:launch]
  before_action :lti_authentication, only: [:launch]
  skip_before_action :verify_authenticity_token, only: [:launch, :login_post, :configure_generate]

  def contains_token_param
    LtiUtils.contains_token_param_raise(params)
  end

  def launch
    tool = LtiTool.find(@lti_launch.lti_tool_id)
    @secret = "&#{tool.shared_secret}"
    @message = (@lti_launch && @lti_launch.message) || LtiUtils.models.generate_message(request.request_parameters)
    @header = SimpleOAuth::Header.new(:post, request.url, @message.post_params, consumer_key: @message.oauth_consumer_key, consumer_secret: 'secret', callback: 'about:blank')
    # render json: JSON.pretty_generate({ launch: params })

    @launch_id = @lti_launch.id
    @tool_id = @lti_launch.lti_tool_id
    custom_params = @message.custom_params
    custom = LtiUtils.no_prefix_custom(custom_params)
    config = custom[:lti_config]
    config = LtiUtils.decrypt_json(config)
    person = { email: custom[:person_email_primary], name: custom[:person_name_full] }

    token_data = {
      tool_id: @tool_id,
      role: LtiUtils::LtiRole.new(custom_params).as_json[:role],
      ip_addr: request.remote_ip
    }

    params[:lti_token] = LtiUtils.encrypt_json(token_data)

    is_student = LtiUtils.verify_student(params)
    is_teacher = LtiUtils.verify_teacher(params)

    user = create_student('student2@student.com', 'Student2') if is_student # create_student(person[:email], person[:name])

    user = User.find_by_email(config[:email]) if is_teacher # || 'teacher@teacher.com' person[:email] -- create_teacher(person[:email], person[:name])

    create_session(user)  if is_student || is_teacher

    LtiUtils.update_and_set_token(params, cookies, session, LtiUtils.update_user_id(params, user.nil? ? nil : user.id))

    aid_valid = config[:aid].nil? || config[:cid].nil? ? false : Assignment.where({ id: config[:aid], course: config[:cid] }).any?

    if is_student
      if aid_valid
        LtiUtils.update_and_set_token(params, cookies, session, { submission: { aid: config[:aid] } })
        redirect_to new_submission_path(aid: config[:aid])
      else
        raise LtiLaunch::Unauthorized, :invalid
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

    redirect_to lti_home_path
  end

  def login
    redirect_to action: :configure if current_user
  end

  def login_post
    u = User.find_by_email(params[:user][:email])
    valid_user = u.valid_password?(params[:user][:password])
    is_admin = u && u.admin?

    validate_login = !valid_user || LtiUtils.invalid_token(params) || !@is_teacher || !is_admin

    if validate_login
      redirect_to action: :login
      return
    end

    create_session(u)

    LtiUtils.update_and_set_token(params, cookies, session, LtiUtils.update_user_id(params, u.id))

    if LtiUtils.from_generator(params)
      redirect_to action: :configure
      return
    end

    redirect_to lti_home_path
  end

  def logout
    unless LtiUtils.invalid_token(params)
      lti_session = LtiSession.find_by_lti_tool_id(LtiUtils.get_tool_id(params))

      lti_session.delete if lti_session && @is_teacher

      LtiUtils.update_and_set_token(params, cookies, session, LtiUtils.update_user_id(params, nil))
    end

    redirect_to lti_home_path
  end

  def index; end

  def configure
    redirect_to action: :login unless current_user
  end

  def configure_generate
    aid = params[:assignment]
    assignment = Assignment.find(aid)
    cid = assignment.course.id unless assignment.nil?
    u = current_user
    render json: { config: u.nil? || cid.nil? ? 'Error' : LtiUtils.encrypt_json({ aid: aid, cid: cid, email: u.email }) }
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
