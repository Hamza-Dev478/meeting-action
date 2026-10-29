require "test_helper"

class Ai::ResponseValidatorTest < ActiveSupport::TestCase
  NOTES = "Maya will send the launch checklist by 2027-02-12. Leo will book the review room by 2027-02-15. " \
          "The team also discussed the new logo without deciding anything."

  def item(overrides = {})
    {
      "description" => "Send the launch checklist",
      "owner" => "Maya",
      "due_date" => "2027-02-12",
      "source_quote" => "Maya will send the launch checklist by 2027-02-12."
    }.merge(overrides)
  end

  def validate(items, notes: NOTES)
    raw = items.is_a?(String) ? items : JSON.generate("action_items" => items)
    Ai::ResponseValidator.call(raw: raw, notes: notes)
  end

  def assert_invalid(reason, raw)
    error = assert_raises(Ai::InvalidResponse) { Ai::ResponseValidator.call(raw: raw, notes: NOTES) }
    assert_equal reason, error.reason
  end

  test "a well-formed grounded item is kept with a Date due date" do
    result = validate([ item ])

    assert_equal 1, result.items.size
    assert_equal({ description: "Send the launch checklist", owner: "Maya", due_date: Date.new(2027, 2, 12),
                   source_quote: "Maya will send the launch checklist by 2027-02-12." }, result.items.first)
    assert_empty result.rejections
    assert_empty result.warnings
  end

  test "an empty list is a valid answer with no items" do
    assert_empty validate([]).items
  end

  test "non-JSON output is rejected as a whole" do
    assert_invalid :not_json, "{this is not valid JSON"
    assert_invalid :not_json, ""
  end

  test "the wrong top-level shape is rejected as a whole" do
    assert_invalid :wrong_shape, "[]"
    assert_invalid :wrong_shape, JSON.generate("items" => [])
    assert_invalid :wrong_shape, JSON.generate("action_items" => "none")
    assert_invalid :wrong_shape, JSON.generate("action_items" => [], "note" => "extra")
  end

  test "items with missing or extra keys are rejected as a whole" do
    assert_invalid :wrong_item_shape, JSON.generate("action_items" => [ item.except("owner") ])
    assert_invalid :wrong_item_shape, JSON.generate("action_items" => [ item.merge("approved" => true) ])
    assert_invalid :wrong_item_shape, JSON.generate("action_items" => [ "Send the checklist" ])
  end

  test "fields with the wrong JSON type are rejected as a whole" do
    assert_invalid :wrong_field_type, JSON.generate("action_items" => [ item("description" => 42) ])
    assert_invalid :wrong_field_type, JSON.generate("action_items" => [ item("owner" => 7) ])
    assert_invalid :wrong_field_type, JSON.generate("action_items" => [ item("due_date" => 20270212) ])
    assert_invalid :wrong_field_type, JSON.generate("action_items" => [ item("source_quote" => nil) ])
  end

  test "more items than the limit is rejected as a whole" do
    assert_invalid :too_many_items, JSON.generate("action_items" => Array.new(26) { item })
  end

  test "an item whose quote is not in the notes is dropped" do
    result = validate([ item("source_quote" => "Maya promised to send a checklist soon.") ])

    assert_empty result.items
    assert_equal [ { index: 0, reason: "unsupported_source_quote" } ], result.rejections
  end

  test "a quote that differs only in whitespace is accepted" do
    notes = "Maya will send the launch checklist\n   by 2027-02-12. Nothing else."

    result = validate([ item ], notes: notes)

    assert_equal 1, result.items.size
  end

  test "a blank description drops the item" do
    result = validate([ item("description" => "   ") ])

    assert_empty result.items
    assert_equal "blank_description", result.rejections.sole[:reason]
  end

  test "an owner who never appears in the notes is cleared, not invented" do
    result = validate([ item("owner" => "Priya") ])

    assert_nil result.items.sole[:owner]
    assert_equal({ index: 0, field: "owner", reason: "owner_not_in_quote" }, result.warnings.sole)
  end

  test "a blank owner becomes nil" do
    assert_nil validate([ item("owner" => " ") ]).items.sole[:owner]
  end

  test "relative or impossible due dates are cleared" do
    assert_nil validate([ item("due_date" => "next Friday") ]).items.sole[:due_date]
    assert_nil validate([ item("due_date" => "2027-02-30") ]).items.sole[:due_date]
    assert_equal "due_date_invalid", validate([ item("due_date" => "next Friday") ]).warnings.sole[:reason]
  end

  test "a valid due date that the notes never state is cleared" do
    result = validate([ item("due_date" => "2027-02-13") ])

    assert_nil result.items.sole[:due_date]
    assert_equal "due_date_not_in_quote", result.warnings.sole[:reason]
  end

  test "a written-out calendar date in the notes supports the ISO due date" do
    notes = "Maya will send the launch checklist by February 12, 2027."
    quote = "Maya will send the launch checklist by February 12, 2027."

    result = validate([ item("source_quote" => quote) ], notes: notes)

    assert_equal Date.new(2027, 2, 12), result.items.sole[:due_date]
  end

  test "duplicate items collapse to one" do
    result = validate([ item, item ])

    assert_equal 1, result.items.size
    assert_equal "duplicate", result.rejections.sole[:reason]
  end

  test "control characters are stripped from text fields" do
    result = validate([ item("description" => "Send the\u0000 launch checklist\u0007") ])

    assert_equal "Send the launch checklist", result.items.sole[:description]
  end

  test "a quote that is not a whole-word excerpt is dropped" do
    [ "a", "aya will send the launch checklist", "Maya will send the launch check" ].each do |fragment|
      result = validate([ item("source_quote" => fragment) ])

      assert_empty result.items, "#{fragment.inspect} should not count as a supporting excerpt"
      assert_equal "unsupported_source_quote", result.rejections.sole[:reason]
    end
  end

  test "a quote shorter than three words is dropped" do
    result = validate([ item("source_quote" => "launch checklist") ])

    assert_empty result.items
    assert_equal "source_quote_too_short", result.rejections.sole[:reason]
  end

  test "an owner or date stated elsewhere in the notes but not in the item's quote is cleared" do
    notes = "Decision: prepare the budget summary. The first note says Priya owns it with a deadline of 2027-02-18. " \
            "A second note says Omar owns it with a deadline of 2027-02-22."
    conflicting = item("description" => "Prepare the budget summary", "owner" => "Priya", "due_date" => "2027-02-18",
                       "source_quote" => "Decision: prepare the budget summary.")

    result = validate([ conflicting ], notes: notes)

    assert_nil result.items.sole[:owner]
    assert_nil result.items.sole[:due_date]
    assert_equal %w[owner_not_in_quote due_date_not_in_quote], result.warnings.map { |w| w[:reason] }
  end
end
