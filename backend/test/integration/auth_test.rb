require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  test "requests without a token are rejected with a JSON error" do
    get "/api/v1/me"

    assert_response :unauthorized
    assert_equal "unauthorized", error_code
  end

  test "requests with an unknown token are rejected" do
    get "/api/v1/me", headers: { "Authorization" => "Bearer not-a-real-token" }

    assert_response :unauthorized
  end

  test "dev session issues a token that authenticates the seeded user" do
    post "/api/v1/dev/session", params: { email: "MAYA@acme.test" }, as: :json

    assert_response :ok
    token = json.fetch("token")
    assert_equal "Maya Chen", json.dig("user", "name")

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    assert_equal "Maya Chen", json.dig("user", "name")
    assert_equal "Acme Robotics", json.dig("user", "organization", "name")
  end

  test "the stored credential is a digest, not the token itself" do
    post "/api/v1/dev/session", params: { email: users(:maya).email }, as: :json

    token = json.fetch("token")
    refute_equal token, users(:maya).reload.api_token_digest
    assert_equal User.digest(token), users(:maya).api_token_digest
  end

  test "dev session rejects unknown emails" do
    post "/api/v1/dev/session", params: { email: "nobody@example.test" }, as: :json

    assert_response :not_found
    assert_equal "not_found", error_code
  end

  test "dev users endpoint lists seeded users for the sign-in picker" do
    get "/api/v1/dev/users"

    assert_response :ok
    emails = json.fetch("users").map { |user| user["email"] }
    assert_includes emails, "maya@acme.test"
    assert_includes emails, "nina@globex.test"
    assert(json.fetch("users").all? { |user| user.dig("organization", "name").present? })
  end
end
