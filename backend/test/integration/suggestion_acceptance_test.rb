require "test_helper"

class SuggestionAcceptanceTest < ActionDispatch::IntegrationTest
  setup do
    @headers = auth_headers_for(users(:maya))
    @suggestion = suggestions(:acme_checklist)
  end

  def accept(suggestion = @suggestion, **fields)
    body = fields.empty? ? {} : { action_item: fields }
    post "/api/v1/suggestions/#{suggestion.id}/accept", headers: @headers, params: body, as: :json
  end

  test "accepting with edits stores the reviewer's values and keeps the original quote" do
    accept(description: "Send the final launch checklist", owner: "Maya Chen", due_date: "2027-02-11")

    assert_response :created
    item = ActionItem.find(json.dig("action_item", "id"))
    assert_equal "Send the final launch checklist", item.description
    assert_equal "Maya Chen", item.owner
    assert_equal Date.new(2027, 2, 11), item.due_date
    assert_equal "Maya will send the launch checklist by 2027-02-12.", item.source_quote
    assert json.dig("action_item", "edited")
    assert_equal "Send the launch checklist", json.dig("action_item", "original", "description")
    assert @suggestion.reload.accepted?
  end

  test "accepting without edits uses the suggestion as proposed" do
    accept

    assert_response :created
    refute json.dig("action_item", "edited")
    assert_equal "2027-02-12", json.dig("action_item", "due_date")
  end

  test "an empty owner or due date clears the field" do
    accept(owner: "", due_date: "")

    assert_response :created
    assert_nil json.dig("action_item", "owner")
    assert_nil json.dig("action_item", "due_date")
  end

  test "accepting the same suggestion twice returns the first action and creates nothing new" do
    accept(description: "First decision")
    first_id = json.dig("action_item", "id")

    assert_no_difference -> { ActionItem.count } do
      accept(description: "Second decision")
    end

    assert_response :ok
    assert_equal first_id, json.dig("action_item", "id")
    assert_equal "First decision", ActionItem.find(first_id).description
    refute json["created"]
  end

  test "a superseded or dismissed suggestion cannot be accepted" do
    @suggestion.update!(status: :superseded)
    accept
    assert_response :conflict
    assert_equal "suggestion_not_pending", error_code

    suggestions(:acme_room).update!(status: :dismissed)
    accept(suggestions(:acme_room))
    assert_response :conflict
  end

  test "an impossible or relative due date is rejected and nothing changes" do
    [ "2027-02-30", "next Friday", "02/12/2027" ].each do |bad_date|
      assert_no_difference -> { ActionItem.count } do
        accept(due_date: bad_date)
      end
      assert_response :unprocessable_content
      assert json.dig("error", "details", "due_date").present?, "expected a due_date error for #{bad_date.inspect}"
    end
    assert @suggestion.reload.pending?
  end

  test "a blank description is rejected" do
    accept(description: "   ")

    assert_response :unprocessable_content
    assert json.dig("error", "details", "description").present?
  end

  test "dismissing hides a pending suggestion and is idempotent" do
    2.times do
      post "/api/v1/suggestions/#{@suggestion.id}/dismiss", headers: @headers
      assert_response :ok
    end

    assert @suggestion.reload.dismissed?
    get "/api/v1/meetings/#{@suggestion.meeting_id}", headers: @headers
    refute_includes json["suggestions"].map { |s| s["id"] }, @suggestion.id
  end

  test "an accepted suggestion cannot be dismissed" do
    accept
    post "/api/v1/suggestions/#{@suggestion.id}/dismiss", headers: @headers

    assert_response :conflict
  end
end
