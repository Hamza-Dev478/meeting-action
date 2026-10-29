require "test_helper"

class MeetingsApiTest < ActionDispatch::IntegrationTest
  setup { @headers = auth_headers_for(users(:maya)) }

  test "lists only the signed-in user's organization meetings, newest first" do
    newer = organizations(:acme).meetings.create!(title: "Retro", notes: "Nothing decided.", author: users(:leo))

    get "/api/v1/meetings", headers: @headers

    assert_response :ok
    ids = json.fetch("meetings").map { |meeting| meeting["id"] }
    assert_equal [ newer.id, meetings(:acme_launch).id ], ids
    assert_equal "Retro", json["meetings"].first["title"]
    assert json["meetings"].first.key?("notes_preview")
  end

  test "creates a meeting in the user's organization regardless of submitted organization" do
    post "/api/v1/meetings", headers: @headers, as: :json,
         params: { meeting: { title: "  Budget review ", notes: "Decision: prepare the budget summary.",
                              organization_id: organizations(:globex).id } }

    assert_response :created
    meeting = Meeting.find(json.dig("meeting", "id"))
    assert_equal organizations(:acme), meeting.organization
    assert_equal users(:maya), meeting.author
    assert_equal "Budget review", meeting.title
    assert_equal "Decision: prepare the budget summary.", json.dig("meeting", "notes")
    assert_equal [], json["suggestions"]
    assert_nil json["latest_generation"]
  end

  test "rejects a meeting without a title or notes with field errors" do
    post "/api/v1/meetings", headers: @headers, as: :json, params: { meeting: { title: " ", notes: "" } }

    assert_response :unprocessable_content
    assert_equal "validation_failed", error_code
    assert json.dig("error", "details", "title").present?
    assert json.dig("error", "details", "notes").present?
  end

  test "rejects notes over the length limit" do
    post "/api/v1/meetings", headers: @headers, as: :json,
         params: { meeting: { title: "Long", notes: "a" * (Meeting::NOTES_MAX_LENGTH + 1) } }

    assert_response :unprocessable_content
  end

  test "shows a meeting with its pending suggestions, accepted actions and latest run" do
    get "/api/v1/meetings/#{meetings(:acme_launch).id}", headers: @headers

    assert_response :ok
    assert_equal meetings(:acme_launch).notes, json.dig("meeting", "notes")
    assert_equal "succeeded", json.dig("latest_generation", "status")
    assert_equal [ "Send the launch checklist", "Book the review room" ], json["suggestions"].map { |s| s["description"] }
    assert_equal "2027-02-12", json["suggestions"].first["due_date"]
    assert_equal [], json["action_items"]
  end
end
