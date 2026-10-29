require "test_helper"

class Ai::Providers::FakeTest < ActiveSupport::TestCase
  LAUNCH_NOTES = "Maya will send the launch checklist by 2027-02-12. Leo will book the review room by 2027-02-15. " \
                 "The team also discussed the new logo without deciding anything."

  teardown { Ai::Providers::Fake.clear_mode! }

  test "heuristic mode returns explicit commitments as provider-shaped JSON" do
    raw = Ai::Providers::Fake.new.extract(title: "Launch planning", notes: LAUNCH_NOTES)
    items = JSON.parse(raw).fetch("action_items")

    assert_equal 2, items.size
    assert_equal({ "description" => "Send the launch checklist", "owner" => "Maya", "due_date" => "2027-02-12",
                   "source_quote" => "Maya will send the launch checklist by 2027-02-12." }, items.first)
    assert_equal "Leo", items.second["owner"]
    assert_equal "2027-02-15", items.second["due_date"]
  end

  test "heuristic mode turns a bare decision into an item with no owner or date" do
    raw = Ai::Providers::Fake.new.extract(title: "Docs", notes: "Decision: update the onboarding guide. Nobody was assigned.")
    items = JSON.parse(raw).fetch("action_items")

    assert_equal [ { "description" => "Update the onboarding guide", "owner" => nil, "due_date" => nil,
                     "source_quote" => "Decision: update the onboarding guide." } ], items
  end

  test "an injected raw response is returned verbatim" do
    provider = Ai::Providers::Fake.new(raw_response: "{this is not valid JSON")

    assert_equal "{this is not valid JSON", provider.extract(title: "t", notes: "n")
  end

  test "an injected timeout raises a retryable provider timeout" do
    error = assert_raises(Ai::ProviderTimeout) { Ai::Providers::Fake.new(error: :timeout).extract(title: "t", notes: "n") }

    assert_equal "provider_timeout", error.code
    assert error.retryable?
  end

  test "an injected provider error raises a retryable provider error" do
    error = assert_raises(Ai::ProviderError) { Ai::Providers::Fake.new(error: :error).extract(title: "t", notes: "n") }

    assert_equal "provider_unavailable", error.code
    assert error.retryable?
  end

  test "a _once mode fails one attempt and then recovers" do
    Ai::Providers::Fake.write_mode!("malformed_once")

    assert_equal "{this is not valid JSON", Ai::Providers::Fake.new.extract(title: "t", notes: LAUNCH_NOTES)
    assert_equal 2, JSON.parse(Ai::Providers::Fake.new.extract(title: "t", notes: LAUNCH_NOTES))["action_items"].size
  end

  test "unknown modes are rejected" do
    assert_raises(ArgumentError) { Ai::Providers::Fake.write_mode!("explode") }
  end
end
