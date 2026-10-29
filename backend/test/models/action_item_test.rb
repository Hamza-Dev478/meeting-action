require "test_helper"

class ActionItemTest < ActiveSupport::TestCase
  test "the database refuses a second action for the same suggestion" do
    suggestion = suggestions(:acme_checklist)
    attributes = {
      meeting: suggestion.meeting,
      suggestion: suggestion,
      accepted_by: users(:maya),
      description: suggestion.description,
      source_quote: suggestion.source_quote
    }
    ActionItem.create!(attributes)

    assert_raises(ActiveRecord::RecordNotUnique) do
      ActionItem.new(attributes).save!(validate: false)
    end
  end

  test "edited? compares the accepted fields against the original suggestion" do
    action = action_items(:globex_style_guide_action)
    refute action.edited?

    action.owner = "Nina"
    assert action.edited?
  end
end
