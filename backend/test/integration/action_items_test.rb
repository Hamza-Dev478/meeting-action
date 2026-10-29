require "test_helper"

class ActionItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:maya)
    @headers = auth_headers_for(@user)
  end

  def accept(suggestion)
    post "/api/v1/suggestions/#{suggestion.id}/accept", headers: @headers, as: :json
    json.dig("action_item", "id")
  end

  def set_completed(id, value, headers: @headers)
    patch "/api/v1/action_items/#{id}", headers: headers, params: { action_item: { completed: value } }, as: :json
  end

  test "accepted actions are listed and filtered by completion" do
    open_id = accept(suggestions(:acme_checklist))
    done_id = accept(suggestions(:acme_room))
    set_completed(done_id, true)

    get "/api/v1/action_items", params: { status: "open" }, headers: @headers
    assert_equal [ open_id ], json["action_items"].map { |a| a["id"] }

    get "/api/v1/action_items", params: { status: "completed" }, headers: @headers
    assert_equal [ done_id ], json["action_items"].map { |a| a["id"] }

    get "/api/v1/action_items", headers: @headers
    assert_equal [ open_id, done_id ].sort, json["action_items"].map { |a| a["id"] }.sort
    assert_equal "Launch planning", json["action_items"].first.dig("meeting", "title")
  end

  test "completion state is persisted and survives a new session" do
    id = accept(suggestions(:acme_checklist))

    set_completed(id, true)
    assert_response :ok
    assert json.dig("action_item", "completed")
    assert ActionItem.find(id).completed_at.present?

    # A fresh sign-in stands in for restarting the app: nothing is client state.
    fresh_headers = auth_headers_for(@user)
    get "/api/v1/action_items", params: { status: "completed" }, headers: fresh_headers
    item = json["action_items"].sole
    assert_equal id, item["id"]
    assert item["completed"]
    assert_equal "Maya will send the launch checklist by 2027-02-12.", item["source_quote"]

    set_completed(id, false, headers: fresh_headers)
    assert_nil ActionItem.find(id).completed_at
  end

  test "marking complete twice keeps the first completion time" do
    id = accept(suggestions(:acme_checklist))
    set_completed(id, true)
    first_completed_at = ActionItem.find(id).completed_at

    travel 1.hour do
      set_completed(id, true)
    end

    assert_equal first_completed_at, ActionItem.find(id).completed_at
  end

  test "completed must be a boolean" do
    id = accept(suggestions(:acme_checklist))

    set_completed(id, "maybe")
    assert_response :bad_request

    patch "/api/v1/action_items/#{id}", headers: @headers, params: { action_item: { description: "x" } }, as: :json
    assert_response :bad_request
  end

  test "an unknown status filter is rejected" do
    get "/api/v1/action_items", params: { status: "archived" }, headers: @headers

    assert_response :bad_request
  end
end
