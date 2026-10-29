# Turns a reviewed suggestion into an action item exactly once.
#
# Concurrent accepts are serialized by a row lock on the suggestion; the unique
# index on action_items.suggestion_id is the invariant that holds even if that
# lock were bypassed. The first acceptance wins; later ones get the existing
# action back unchanged.
class SuggestionAcceptance
  class NotPending < StandardError
    attr_reader :status

    def initialize(status)
      @status = status
      super("Suggestion is #{status}")
    end
  end

  Result = Data.define(:action_item, :created)

  ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/
  EDITABLE_FIELDS = %w[description owner due_date].freeze

  # attrs: reviewer edits; any field left out keeps the suggested value.
  def initialize(suggestion:, user:, attrs: {})
    @suggestion = suggestion
    @user = user
    @attrs = (attrs || {}).to_h.stringify_keys.slice(*EDITABLE_FIELDS)
  end

  def call
    ActiveRecord::Base.transaction do
      @suggestion.lock!
      existing = ActionItem.find_by(suggestion_id: @suggestion.id)
      if existing
        Result.new(action_item: existing, created: false)
      else
        raise NotPending, @suggestion.status unless @suggestion.pending?

        item = build_item
        item.save!
        @suggestion.update!(status: :accepted)
        Result.new(action_item: item, created: true)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    Result.new(action_item: ActionItem.find_by!(suggestion_id: @suggestion.id), created: false)
  end

  private

  def build_item
    description = @attrs.fetch("description", @suggestion.description).to_s.squish
    owner = @attrs.fetch("owner", @suggestion.owner).to_s.squish.presence
    raw_due_date = @attrs.fetch("due_date", @suggestion.due_date&.iso8601).to_s.strip
    due_date = parse_date(raw_due_date)

    item = ActionItem.new(
      meeting: @suggestion.meeting,
      suggestion: @suggestion,
      accepted_by: @user,
      description: description,
      owner: owner,
      due_date: due_date,
      # Provenance: always the original excerpt, whatever the reviewer edited.
      source_quote: @suggestion.source_quote
    )

    item.validate
    if raw_due_date.present? && due_date.nil?
      item.errors.add(:due_date, "must be a real calendar date written as YYYY-MM-DD")
    end
    raise ActiveRecord::RecordInvalid, item if item.errors.any?

    item
  end

  def parse_date(text)
    return nil unless text.match?(ISO_DATE)

    Date.iso8601(text)
  rescue Date::Error
    nil
  end
end
