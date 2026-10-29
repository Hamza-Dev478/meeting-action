require "test_helper"

class Evaluation::RunnerTest < ActiveSupport::TestCase
  test "fake mode grades every fixture case and both injected failures" do
    outcomes = Evaluation::Runner.new(provider_name: "fake").run

    ids = outcomes.map(&:case_id)
    assert_equal %w[explicit_commitment missing_details no_actions conflicting_details instruction_in_notes
                    provider_failures:malformed_output provider_failures:timeout], ids
    assert_equal [ "fake" ], outcomes.map(&:mode).uniq
    assert_equal [ "pass" ], outcomes.map(&:verdict).uniq, outcomes.reject { |o| o.verdict == "pass" }.map(&:notes).inspect
  end

  test "real mode without a key reports extraction cases as blocked, never as passed" do
    outcomes = Evaluation::Runner.new(provider_name: "anthropic", provider: Ai::Providers::Claude.new(api_key: nil)).run

    extraction = outcomes.first(5)
    assert_equal [ "blocked" ], extraction.map(&:verdict).uniq
    assert_equal [ "real" ], extraction.map(&:mode).uniq
    assert_match(/ANTHROPIC_API_KEY/, extraction.first.notes)
  end

  test "turning a discussion into an action fails the case" do
    raw = JSON.generate("action_items" => [
      { "description" => "Write a new onboarding guide", "owner" => nil, "due_date" => nil,
        "source_quote" => "We discussed whether a new onboarding guide would be useful." }
    ])
    runner = Evaluation::Runner.new(provider_name: "fake", provider: Ai::Providers::Fake.new(raw_response: raw))

    outcome = runner.run.find { |o| o.case_id == "no_actions" }

    assert_equal "fail", outcome.verdict
    assert_match(/expected 0 action/, outcome.notes)
  end

  test "a markdown table is rendered with one row per outcome" do
    outcomes = Evaluation::Runner.new(provider_name: "fake").run

    table = Evaluation::Runner.to_markdown(outcomes)

    assert_equal outcomes.size + 2, table.lines.size
    assert_match(/\| explicit_commitment \| fake \|/, table)
  end
end
