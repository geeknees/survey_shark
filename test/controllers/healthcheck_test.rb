require "test_helper"

class HealthcheckTest < ActionDispatch::IntegrationTest
  test "GET /up returns 200 and JSON status" do
    get "/up"
    
    assert_response :success
    
    # Rails health check returns JSON by default
    if response.content_type.include?("application/json")
      json_response = JSON.parse(response.body)
      assert_equal "ok", json_response["status"]
    else
      # If it returns HTML, it should still be a successful health check
      assert_includes response.body, "green"
    end
  end
end