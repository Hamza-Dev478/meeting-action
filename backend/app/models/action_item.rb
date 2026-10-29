class ActionItem < ApplicationRecord
  DESCRIPTION_MAX_LENGTH = 500
  OWNER_MAX_LENGTH = 100

  belongs_to :meeting
  belongs_to :suggestion
  belongs_to :accepted_by, class_name: "User"

  validates :description, presence: true, length: { maximum: DESCRIPTION_MAX_LENGTH }
  validates :owner, length: { maximum: OWNER_MAX_LENGTH }
  validates :source_quote, presence: true

  scope :incomplete, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }

  def completed?
    completed_at.present?
  end

  # True when the reviewer changed what the AI proposed before accepting.
  def edited?
    description != suggestion.description || owner != suggestion.owner || due_date != suggestion.due_date
  end
end
