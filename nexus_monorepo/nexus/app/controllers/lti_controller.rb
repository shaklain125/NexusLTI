require 'ims/lti'
class LtiController < ApplicationController
  include LtiHelper

  before_filter :lti_authentication

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
    # render json: JSON.pretty_generate({ assignments: Assignment.all.to_json })
    # redirect_to new_user_session_path
    @tool_id = @lti_launch.lti_tool_id
  end
end
