module MeetingPayload
  extend ActiveSupport::Concern

  private

  # Full meeting view used by show and create: the notes, the latest
  # generation's status, suggestions awaiting review, and accepted actions.
  def meeting_payload(meeting)
    {
      meeting: ApiJson.meeting_detail(meeting),
      latest_generation: ApiJson.generation(meeting.latest_generation),
      suggestions: meeting.suggestions.pending.order(:position, :id).map { |s| ApiJson.suggestion(s) },
      action_items: meeting.action_items.includes(:suggestion, :accepted_by, :meeting).order(:created_at, :id)
                           .map { |item| ApiJson.action_item(item) }
    }
  end
end
