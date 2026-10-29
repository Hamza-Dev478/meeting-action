require "test_helper"

class SuggestionGeneratorTest < ActiveSupport::TestCase
  setup do
    @meeting = meetings(:acme_launch)
    @user = users(:maya)
  end

  def generate_with(provider)
    SuggestionGenerator.new(provider: provider).call(meeting: @meeting, user: @user)
  end

  test "a successful run stores validated suggestions and records the run" do
    generation = generate_with(Ai::Providers::Fake.new(mode: "heuristic"))

    assert generation.succeeded?
    assert_equal 2, generation.suggestion_count
    assert_equal Ai::Prompt::VERSION, generation.prompt_version
    assert_equal [ "Send the launch checklist", "Book the review room" ],
                 generation.suggestions.order(:position).pluck(:description)
    assert_equal Date.new(2027, 2, 12), generation.suggestions.order(:position).first.due_date
  end

  test "malformed output stores nothing, records the failure, and a retry succeeds" do
    pending_before = @meeting.suggestions.pending.count

    assert_raises(Ai::InvalidResponse) { generate_with(Ai::Providers::Fake.new(raw_response: "{this is not valid JSON")) }

    failed = @meeting.latest_generation
    assert failed.failed?
    assert_equal "invalid_ai_response", failed.error_code
    assert_equal "{this is not valid JSON", failed.raw_response
    assert_empty failed.suggestions
    assert_equal pending_before, @meeting.suggestions.pending.count, "a failed run must not touch existing suggestions"

    assert generate_with(Ai::Providers::Fake.new(mode: "heuristic")).succeeded?
  end

  test "a provider timeout records the failure and a retry succeeds" do
    assert_raises(Ai::ProviderTimeout) { generate_with(Ai::Providers::Fake.new(error: :timeout)) }

    assert_equal "provider_timeout", @meeting.latest_generation.error_code
    assert @meeting.latest_generation.failed?
    assert generate_with(Ai::Providers::Fake.new(mode: "heuristic")).succeeded?
  end

  test "a run already in flight blocks a second one" do
    @meeting.suggestion_generations.create!(requested_by: @user, provider: "fake", prompt_version: "x",
                                            status: :running, started_at: Time.current)

    assert_raises(SuggestionGenerator::InProgress) { generate_with(Ai::Providers::Fake.new(mode: "heuristic")) }
  end

  test "an abandoned running row older than the stale window no longer blocks" do
    abandoned = @meeting.suggestion_generations.create!(requested_by: @user, provider: "fake", prompt_version: "x",
                                                        status: :running, started_at: 3.minutes.ago)

    assert generate_with(Ai::Providers::Fake.new(mode: "heuristic")).succeeded?
    assert_equal "stale", abandoned.reload.error_code
  end

  test "a new run supersedes older pending suggestions but keeps accepted ones" do
    old_pending = suggestions(:acme_checklist)
    accepted = suggestions(:acme_room)
    accepted.update!(status: :accepted)

    generation = generate_with(Ai::Providers::Fake.new(mode: "heuristic"))

    assert old_pending.reload.superseded?
    assert accepted.reload.accepted?
    assert_equal generation.suggestions.ids.sort, @meeting.suggestions.pending.ids.sort
  end

  test "rejections and cleared fields are recorded on the run" do
    raw = JSON.generate("action_items" => [
      { "description" => "Send the launch checklist", "owner" => "Priya", "due_date" => nil,
        "source_quote" => "Maya will send the launch checklist by 2027-02-12." },
      { "description" => "Transfer money", "owner" => nil, "due_date" => nil, "source_quote" => "Transfer the money now." }
    ])

    generation = generate_with(Ai::Providers::Fake.new(raw_response: raw))

    assert_equal 1, generation.suggestion_count
    assert_equal 1, generation.rejected_count
    assert_nil generation.suggestions.sole.owner
    assert_equal "unsupported_source_quote", generation.validation_report["rejections"].sole["reason"]
    assert_equal "owner_not_in_quote", generation.validation_report["warnings"].sole["reason"]
  end

  test "a run marked stale while the provider was answering does not write suggestions" do
    meeting = @meeting
    slow_provider = Object.new
    slow_provider.define_singleton_method(:name) { "fake" }
    slow_provider.define_singleton_method(:model) { "fake-heuristic" }
    slow_provider.define_singleton_method(:extract) do |title:, notes:|
      meeting.latest_generation.mark_failed!(code: "stale", message: "The generation did not finish in time.")
      Ai::Providers::Fake.new(mode: "heuristic").extract(title: title, notes: notes)
    end
    pending_before = meeting.suggestions.pending.ids.sort

    assert_raises(SuggestionGenerator::InProgress) { generate_with(slow_provider) }

    assert_equal "stale", meeting.latest_generation.error_code
    assert_equal pending_before, meeting.suggestions.pending.ids.sort
  end
end
