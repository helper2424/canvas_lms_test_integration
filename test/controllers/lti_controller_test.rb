require 'test_helper'

class LtiControllerTest < ActionDispatch::IntegrationTest
  test "should get xml" do
    get lti_xml_url
    assert_response :success
  end

  test "should get cred" do
    get lti_cred_url
    assert_response :success
  end

end
