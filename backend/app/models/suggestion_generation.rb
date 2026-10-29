class SuggestionGeneration < ApplicationRecord
  # A run still marked running after this long is treated as abandoned (for
  # example the server process died mid-request) and no longer blocks retries.
  STALE_AFTER = 2.minutes
  RAW_RESPONSE_LIMIT = 10_000

  belongs_to :meeting
  belongs_to :requested_by, class_name: "User"
  has_many :suggestions, dependent: :destroy

  enum :status, { running: "running", succeeded: "succeeded", failed: "failed" }, validate: true

  scope :stale, -> { running.where(started_at: ...STALE_AFTER.ago) }

  def mark_failed!(code:, message:, raw_response: nil)
    update!(
      status: :failed,
      error_code: code,
      error_message: message.to_s.truncate(255),
      raw_response: raw_response&.truncate(RAW_RESPONSE_LIMIT),
      finished_at: Time.current
    )
  end
end
