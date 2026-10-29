require "test_helper"

class ErrorEnvelopeTest < ActionDispatch::IntegrationTest
  test "an unexpected server error on any endpoint uses the JSON error format without internals" do
    original = ApiJson.method(:meeting_summary)
    ApiJson.define_singleton_method(:meeting_summary) { |_meeting| raise "boom: internal detail" }

    get "/api/v1/meetings", headers: auth_headers_for(users(:maya))

    assert_response :internal_server_error
    assert_equal "internal_error", error_code
    assert json.dig("error", "message").present?
    refute_includes response.body, "internal detail"
  ensure
    ApiJson.define_singleton_method(:meeting_summary, original)
  end

  test "a request body that is not valid JSON is a 400 in the error format" do
    post "/api/v1/meetings", params: "{not json", headers: auth_headers_for(users(:maya)).merge("Content-Type" => "application/json")

    assert_response :bad_request
    assert_equal "bad_request", error_code
  end
end
