require "test_helper"

class GenerationApiTest < ActionDispatch::IntegrationTest
  include TestHelpers::ProviderOverride

  setup do
    @meeting = meetings(:acme_launch)
    @headers = auth_headers_for(users(:maya))
    @path = "/api/v1/meetings/#{@meeting.id}/suggestion_generations"
  end

  test "a successful generation returns the new suggestions" do
    use_provider Ai::Providers::Fake.new(mode: "heuristic")

    post @path, headers: @headers

    assert_response :created
    assert_equal "succeeded", json.dig("generation", "status")
    assert_equal [ "Maya", "Leo" ], json["suggestions"].map { |s| s["owner"] }
    assert_equal [ "pending" ], json["suggestions"].map { |s| s["status"] }.uniq
  end

  test "malformed provider output is a retryable error and nothing is stored" do
    use_provider Ai::Providers::Fake.new(raw_response: "{this is not valid JSON")

    assert_no_difference -> { Suggestion.count } do
      post @path, headers: @headers
    end

    assert_response :bad_gateway
    assert_equal "invalid_ai_response", error_code
    assert json.dig("error", "retryable")
    assert_equal 0, ActionItem.where(meeting: @meeting).count

    use_provider Ai::Providers::Fake.new(mode: "heuristic")
    post @path, headers: @headers
    assert_response :created
  end

  test "a provider timeout is a retryable gateway timeout and a later attempt can succeed" do
    use_provider Ai::Providers::Fake.new(error: :timeout)

    post @path, headers: @headers

    assert_response :gateway_timeout
    assert_equal "provider_timeout", error_code
    assert json.dig("error", "retryable")

    use_provider Ai::Providers::Fake.new(mode: "heuristic")
    post @path, headers: @headers
    assert_response :created
  end

  test "a misconfigured provider is reported as not retryable" do
    use_provider Ai::Providers::Claude.new(api_key: nil)

    post @path, headers: @headers

    assert_response :bad_gateway
    assert_equal "provider_misconfigured", error_code
    refute json.dig("error", "retryable")
  end

  test "a second request while one is running gets a conflict" do
    use_provider Ai::Providers::Fake.new(mode: "heuristic")
    @meeting.suggestion_generations.create!(requested_by: users(:maya), provider: "fake", prompt_version: "x",
                                            status: :running, started_at: Time.current)

    post @path, headers: @headers

    assert_response :conflict
    assert_equal "generation_in_progress", error_code
  end

  test "an unknown AI_PROVIDER setting is reported as a misconfigured provider" do
    previous = ENV["AI_PROVIDER"]
    ENV["AI_PROVIDER"] = "openai"

    post @path, headers: @headers

    assert_response :bad_gateway
    assert_equal "provider_misconfigured", error_code
    refute json.dig("error", "retryable")
  ensure
    ENV["AI_PROVIDER"] = previous
  end

  test "an unexpected error during generation uses the error format and a retry works" do
    broken = Ai::Providers::Fake.new
    broken.define_singleton_method(:extract) { |**| raise "boom" }
    use_provider broken

    post @path, headers: @headers

    assert_response :internal_server_error
    assert_equal "internal_error", error_code
    assert json.dig("error", "retryable")
    refute_includes response.body, "boom"
    assert_equal "internal_error", @meeting.latest_generation.error_code

    use_provider Ai::Providers::Fake.new(mode: "heuristic")
    post @path, headers: @headers
    assert_response :created
  end
end
