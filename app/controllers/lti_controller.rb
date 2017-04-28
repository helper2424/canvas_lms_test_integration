class LtiController < ApplicationController
  include Oauth

  before_action :cache_params
  before_action :authenticate_user!

  skip_before_action :authenticate_user!, only: [:xml, :endpoint]

  class EmptyAccessToken < RuntimeError
  end

  def xml
    render xml: render_to_string(layout: false)
  end

  def register
    required_params = [:ext_api_domain, :launch_presentation_return_url]

    ext_domain = params[:ext_api_domain] || session[:ext_api_domain]
    lti_launch_url = params[:launch_presentation_return_url] || session[:launch_presentation_return_url]

    access_token, refresh_token = current_user.get_tokens

    binding.pry
    remove_saved_params required_params
    session.delete :return_to_url

    begin
      create_tool_result = create_external_tool "http://#{ext_domain}", 2, 'some', 'some', access_token, {
        editor_button: {
          enabled: true,
          icon_url: 'https://online.clickview.com.au/Assets/images/icons/cv-logo.png',
          selection_width: 800,
          selection_height: 494,
          url: url_for(controller: :lti, action: :add_content),
          message_type: 'ContentItemSelectionRequest'
        },
        resource_selection: {
          enabled: true,
          url: url_for(:root)
        }
      }
    rescue EmptyAccessToken, RestClient::Unauthorized => e
      unless refresh_token.blank?
        access_token = oauth_refresh_token refresh_token
        if access_token.present?
          tokens = current_user.oauth_token
          tokens.access_token = access_token
          tokens.save
          retry
        end

      end

      save_params_to_session required_params
      session[:return_to_url] = request.original_url
      oauth_start_auth
      return
    end

    url_params = {
      status: 'success', # or failure
      tool_proxy_guid: 1
    }
    redirect_url = "#{lti_launch_url}?#{url_params.to_query}"

    binding.pry
    redirect_to redirect_url
  end

  def add_content
    binding.pry
    @redirect_url = params['launch_presentation_return_url']

    if @redirect_url.blank?
      passed_params = cookies['passed_params']
      @redirect_url = (JSON.parse passed_params rescue {})['launch_presentation_return_url']
      cookies['passed_params'] = nil
    end
    @readings = [[1, 'First'], [2, 'Second'], [3, 'Third']]
  end

  def send_choosen_objects
    # id = SecureRandom.uuid
    #
    # Reading.create uid: id, readings: params['readings'].to_json
    # endpoint_url = url_for(controller: :lti, action: :endpoint, format: :json)
    #
    # url_params = {return_type: 'oembed', url: id, endpoint: endpoint_url}
    # redirect_url = "#{params['launch_presentation_return_url']}?#{url_params.to_query}"
    #
    # redirect_to redirect_url

    # ===============================

    id = SecureRandom.uuid

    Reading.create uid: id, readings: params['readings'].to_json
    url = url_for(controller: :lti, action: :item, id: id)
    url_params = { return_type: 'iframe', url: url,
                   title: 'Item test', width: '400', height: '200' }
    redirect_url = "#{params['launch_presentation_return_url']}?#{url_params.to_query}"

    redirect_to redirect_url
  end

  def endpoint
    # unless params[:url] == url_for(controller: :main, action: :item, id: id)
    #   raise ActionController::RoutingError.new('Not Found')
    # end

    readings = Reading.find_by_uid params['url']
    @readings = JSON.parse readings.readings rescue []

    # self.formats = [:html]
    #   html_rendered = render_to_string(:action => 'item')
    # self.formats = [:json]

    html_rendered = '<iframe id="eres_res_link_1685" src="/d2l/common/dialogs/quickLink/quickLink.d2l?ou=36555&amp;type=lti&amp;rcode=VUUAT-112994&amp;srcou=1" width="100%" frameborder="0" scrolling="no" onload="alert("test");" style="overflow: hidden; height: 98px;"></iframe>'
    html_rendered.concat '<script type="text/javascript">window.alert("Hello World!");</script>'
    html_rendered.concat '<div style="font-size: 30px; color: green; position: absolute; left:30px; top: 30px;">A lot text</div>'

    response = {
      type: 'rich',
      version: '1.0',
      html: html_rendered,
      width: 333,
      height: 444
    }
    render json: response
  end

  def item
    readings = Reading.find_by_uid params['id']
    @readings = JSON.parse readings.readings rescue []
  end

  # return here from lms with code or error
  def oauth
    oauth_back
  end

  protected

  def cache_params
    keys = ["oauth_consumer_key", "oauth_signature_method", "oauth_timestamp", "oauth_nonce", "oauth_version", "context_id", "context_label", "context_title", "custom_canvas_api_domain", "custom_canvas_course_id", "custom_canvas_enrollment_state", "custom_canvas_user_id", "custom_canvas_user_login_id", "custom_canvas_workflow_state", "ext_content_intended_use", "ext_content_return_types", "ext_content_return_url", "ext_roles", "launch_presentation_document_target", "launch_presentation_height", "launch_presentation_locale", "launch_presentation_return_url", "launch_presentation_width", "lis_person_contact_email_primary", "lis_person_name_family", "lis_person_name_full", "lis_person_name_given", "lti_message_type", "lti_version", "oauth_callback", "resource_link_id", "resource_link_title", "roles", "selection_directive", "text", "tool_consumer_info_product_family_code", "tool_consumer_info_version", "tool_consumer_instance_contact_email", "tool_consumer_instance_guid", "tool_consumer_instance_name", "user_id", "user_image", "oauth_signature"]

    passed_params = {}
    keys.each do |i|
      passed_params[i] = params[i] if params[i].present?
    end

    cookies['passed_params'] = passed_params.to_json if passed_params.present?
  end

  def create_external_tool(base_url, course_id, key, secret, access_token, additional_params = {})
    raise EmptyAccessToken.new if access_token.blank?

    tool_params = {
      privacy_level: 'public',
      consumer_key: key,
      shared_secret: secret
    }.merge additional_params

    binding.pry
    response = RestClient.post "#{base_url}/api/v1/courses/#{course_id}/external_tools", tool_params,
                               'Authorization' => " Bearer #{access_token}"
    Oj.load response.body
  end

  def oauth_redirect_url
    url_for(controller: :lti, action: :oauth)
  end
end
