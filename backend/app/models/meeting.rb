class Meeting < ApplicationRecord
  TITLE_MAX_LENGTH = 200
  NOTES_MAX_LENGTH = 20_000

  belongs_to :organization
  belongs_to :author, class_name: "User"

  # Declaration order matters for dependent destroy: actions reference suggestions.
  has_many :action_items, dependent: :destroy
  has_many :suggestions, dependent: :destroy
  has_many :suggestion_generations, dependent: :destroy

  normalizes :title, with: ->(title) { title.strip }

  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :notes, presence: true, length: { maximum: NOTES_MAX_LENGTH }
  validate :author_in_same_organization

  def latest_generation
    suggestion_generations.order(created_at: :desc, id: :desc).first
  end

  private

  def author_in_same_organization
    return if author.nil? || organization_id.nil?

    errors.add(:author, "must belong to the meeting's organization") if author.organization_id != organization_id
  end
end
