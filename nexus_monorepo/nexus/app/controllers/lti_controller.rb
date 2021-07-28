require 'ims/lti'
class LtiController < ApplicationController
  include LtiHelper

  before_filter :lti_authentication, only: [:launch]

  def launch
    tool = LtiTool.find(@lti_launch.lti_tool_id)
    @secret = "&#{tool.shared_secret}"
    @message = (@lti_launch && @lti_launch.message) || IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    @header = SimpleOAuth::Header.new(:post, request.url, @message.post_params, consumer_key: @message.oauth_consumer_key, consumer_secret: 'secret', callback: 'about:blank')
    # render json: JSON.pretty_generate({ 'launch' => { 'message' => @message, 'secret' => @secret, 'header' => @header } })
    # render json: JSON.pretty_generate({ 'launch' => {
    #                                     'params' => params,
    #                                     'lti_launch' => @lti_launch.as_json,
    #                                     'lti_tool' => tool.as_json
    #                                   } })
    # render json: JSON.pretty_generate({ launch: params })

    params[:lti_user] = 1
    # redirect_to edit_assignment_path(1)
    # redirect_to lti_launch2_path
    # render json: JSON.pretty_generate({
    #                                     signed_in: user_signed_in?,
    #                                     current_user: current_user.as_json
    #                                   })
  end

  def launch2
    # redirect_to lti_launch3_path
    render json: JSON.pretty_generate({ params: params })
    # render json: JSON.pretty_generate({ user: current_user.as_json })
  end

  def launch3
    render json: JSON.pretty_generate({ user: current_user.as_json })
  end
end
