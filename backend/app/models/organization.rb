class Organization < ApplicationRecord
  # Meetings first: their author foreign key must be gone before users are destroyed.
  has_many :meetings, dependent: :destroy
  has_many :users, dependent: :destroy
  # Scoped lookups for nested records always go through these associations, so a
  # guessed ID from another organization resolves to RecordNotFound (404).
  has_many :suggestions, through: :meetings
  has_many :action_items, through: :meetings

  validates :name, presence: true, uniqueness: true
end
