class Suggestion < ApplicationRecord
  belongs_to :meeting
  belongs_to :suggestion_generation
  has_one :action_item, dependent: :restrict_with_exception

  enum :status, {
    pending: "pending",
    accepted: "accepted",
    dismissed: "dismissed",
    superseded: "superseded"
  }, validate: true

  validates :description, :source_quote, presence: true
end
