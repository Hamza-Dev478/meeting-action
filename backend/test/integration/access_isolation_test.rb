require "test_helper"

# Globex users must not read or change anything belonging to Acme (and vice
# versa), even with valid IDs taken from the other organization.
class AccessIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @acme_meeting = meetings(:acme_launch)
    @acme_suggestion = suggestions(:acme_checklist)
    @acme_action = ActionItem.create!(meeting: @acme_meeting, suggestion: suggestions(:acme_room), accepted_by: users(:maya),
                                      description: "Book the review room", source_quote: suggestions(:acme_room).source_quote)
    @globex = auth_headers_for(users(:nina))
    @acme = auth_headers_for(users(:maya))
  end

  def assert_not_found
    assert_response :not_found
    assert_equal "not_found", error_code
  end

  test "lists never include the other organization's records" do
    get "/api/v1/meetings", headers: @globex
    refute_includes json["meetings"].map { |m| m["id"] }, @acme_meeting.id

    get "/api/v1/action_items", headers: @globex
    refute_includes json["action_items"].map { |a| a["id"] }, @acme_action.id

    get "/api/v1/action_items", headers: @acme
    refute_includes json["action_items"].map { |a| a["id"] }, action_items(:globex_style_guide_action).id
  end

  test "reading another organization's meeting looks the same as a missing one" do
    get "/api/v1/meetings/#{@acme_meeting.id}", headers: @globex
    assert_not_found

    get "/api/v1/meetings/999999999", headers: @globex
    assert_not_found
  end

  test "generating suggestions for another organization's meeting is refused" do
    assert_no_difference -> { SuggestionGeneration.count } do
      post "/api/v1/meetings/#{@acme_meeting.id}/suggestion_generations", headers: @globex
    end
    assert_not_found
  end

  test "accepting or dismissing another organization's suggestion is refused" do
    assert_no_difference -> { ActionItem.count } do
      post "/api/v1/suggestions/#{@acme_suggestion.id}/accept", headers: @globex, as: :json,
           params: { action_item: { description: "Hijacked" } }
    end
    assert_not_found

    post "/api/v1/suggestions/#{@acme_suggestion.id}/dismiss", headers: @globex
    assert_not_found
    assert @acme_suggestion.reload.pending?
  end

  test "completing another organization's action is refused" do
    patch "/api/v1/action_items/#{@acme_action.id}", headers: @globex, as: :json,
          params: { action_item: { completed: true } }

    assert_not_found
    assert_nil @acme_action.reload.completed_at
  end
end
