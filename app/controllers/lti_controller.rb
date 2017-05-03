class LtiController < ApplicationController
  include Oauth

  before_action :authenticate_user!

  skip_before_action :authenticate_user!, only: [:xml, :endpoint, :add_content, :item]

  OAUTH1_KEY = 'item_tool'
  OAUTH1_SECRET = 'item_tool_secret'

  def register
    begin
      tc_profile = RestClient.get params['tc_profile_url']
    rescue RestClient::ExceptionWithResponse => e
      # Handle this
    end

    tool_proxy_services = Oj.load tc_profile
    register_request = nil

    tool_proxy_services['service_offered'].each do |i|
      if i['format'].include?('application/vnd.ims.lti.v2.toolproxy+json') && i['action'].include?('POST')
        register_request = i['endpoint']
      end
    end


    begin
      add_content_url = url_for(controller: :lti, action: :add_content)
      content_body = { '@context' => add_content_url }.to_json
      oauth_params = {
        'realm' => '',
        'oauth_version' => "1.0",
        'oauth_nonce' => 'nonce',
        'oauth_timestamp' => Time.now.to_i,
        'oauth_consumer_key' => params['reg_key'],
        'oauth_body_hash' => URI.encode_www_form_component(Digest::SHA1.base64digest(content_body)),
        'oauth_signature_method' => "HMAC-SHA1"
      }

      signature = oauth1_signature('POST',
                                   register_request,
                                   oauth_params,
                                   params['reg_password'])

      oauth_params['oauth_signature'] = URI.encode_www_form_component signature
      oauth_header = oauth_params.map { |k, v| "#{k} = \"#{v}\"" }.join ','

      reg_result = RestClient.post register_request, content_body,
                                   'Content-Type' => 'application/vnd.ims.lti.v2.toolproxy+json',
                                   'Authorization' => "OAuth #{oauth_header}"
    rescue RestClient::ExceptionWithResponse => e
      # Handle this
    end

    url_params = {
      status: 'success', # or failure
      tool_proxy_guid: params[:ext_tool_consumer_instance_guid] #create_tool_result['id']
    }
    redirect_url = "#{lti_launch_url}?#{url_params.to_query}"

    redirect_to redirect_url
  end

  def add_content
    # check_lti_auth 'some'
    authenticate_user!
    @params_inner = params.select { |k, v| not [:controller, :action].include? k.to_sym }
    @readings = [[1, 'First'], [2, 'Second'], [3, 'Third']]
  end

  def send_choosen_objects
    id = SecureRandom.uuid

    Reading.create uid: id, readings: params['readings'].to_json

    tokens = current_user.oauth_token
    access_token = tokens.access_token
    refresh_token = tokens.refresh_token

    course_id = 2 # Extract by youself

    item_tool = nil
    launch_items_url = url_for(controller: :lti, action: :item, id: id)

    unless item_tool
      return unless api_call_wrapper(access_token, refresh_token) do |access_token_real|
        item_tool = create_external_tool OAUTH_BASE_URL, course_id, OAUTH1_KEY, OAUTH1_SECRET,
                                         access_token_real, additional_params = {
            url: launch_items_url = url_for(controller: :lti, action: :item, id: id),
            name: "Item Tool #{id}",
            course_navigation: {
              enabled: true,
              text: "Ereserve plus #{id}",
              visibility: 'admins',
              windowTarget: '_blank',
              default: false
            },
          }
      end

      return unless api_call_wrapper(access_token, refresh_token) do |access_token_real|
        delete_external_tool OAUTH_BASE_URL, item_tool['id'], course_id, access_token_real
      end
    end

    launch_url = "/courses/#{course_id}/external_tools/#{item_tool['id']}?display=borderless"
    url_params = { return_type: 'iframe', url: launch_url,
                   title: 'Item test' }
    redirect_url = "#{params['content_item_return_url']}?#{url_params.to_query}"

    redirect_to redirect_url
  end

  def item
    check_lti_auth OAUTH1_SECRET
    readings = Reading.find_by_uid params['id']
    @readings = JSON.parse readings.readings rescue []
  end

  # return here from lms with code or error
  def oauth
    oauth_back
  end

  protected

  def create_external_tool(base_url, course_id, key, secret, access_token, additional_params = {})
    tool_params = {
      privacy_level: 'public',
      consumer_key: key,
      shared_secret: secret
    }.merge additional_params

    response = RestClient.post "#{base_url}/api/v1/courses/#{course_id}/external_tools", tool_params,
                               'Authorization' => " Bearer #{access_token}"
    Oj.load response.body
  end

  def get_external_tools_list(base_url, access_token, course_id)
    Oj.load RestClient.get("#{base_url}/api/v1/courses/#{course_id}/external_tools",
                           oauth2_header(access_token)).body
  end

  def delete_external_tool(base_url, id, course_id, access_token)
    Oj.load RestClient.delete("#{base_url}/api/v1/courses/#{course_id}/external_tools/#{id}",
                              oauth2_header(access_token)).body
  end

  def session_less_url_external_tool(base_url, access_token, course_id, id)
    Oj.load RestClient.get("#{base_url}/api/v1/courses/#{course_id}/external_tools/sessionless_launch?#{ { id: id }.to_query }",
                           oauth2_header(access_token)).body
  end

  def oauth_redirect_url
    url_for(controller: :lti, action: :oauth)
  end

  def check_lti_auth(secret)
    lti_auth = IMS::LTI::Services::MessageAuthenticator.new(request.url,
                                                            request.request_parameters,
                                                            secret)

    raise ActionController::RoutingError.new('Not Authrorised') unless lti_auth.valid_signature?
  end

  def oauth1_signature(method, url, post_params, secret)
    post_params = post_params.sort.map { |i| "#{i[0]}=#{i[1]}" }.join '&'
    data = "#{method}&#{URI.encode_www_form_component url}&#{URI.encode_www_form_component post_params }"
    Base64.encode64(OpenSSL::HMAC.digest('SHA1', secret, data)).strip()
  end
end
