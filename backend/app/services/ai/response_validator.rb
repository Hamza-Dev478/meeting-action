module Ai
  # The only path from raw provider text to storable suggestions.
  #
  # Structure and JSON types are all-or-nothing: if the provider breaks the
  # contract, nothing from that response is trusted (raises InvalidResponse).
  # Grounding is checked per item: an item whose quote is not a whole-word
  # excerpt of the notes (at least MIN_QUOTE_WORDS words) is dropped, and an
  # owner or due date that the item's own quote does not state is cleared.
  #
  # Limits: this cannot tell whether the quote really expresses a commitment,
  # whether the description matches the quote, or whether the owner named in
  # the quote is the assignee. Those depend on the model and on human review.
  class ResponseValidator
    MAX_ITEMS = 25
    DESCRIPTION_MAX_LENGTH = ActionItem::DESCRIPTION_MAX_LENGTH
    OWNER_MAX_LENGTH = ActionItem::OWNER_MAX_LENGTH
    QUOTE_MAX_LENGTH = 1_000
    MIN_QUOTE_WORDS = 3
    ITEM_KEYS = %w[description owner due_date source_quote].freeze
    ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/
    CONTROL_CHARACTERS = /[[:cntrl:]&&[^\n\t]]/
    TYPOGRAPHIC = { "‘" => "'", "’" => "'", "“" => '"', "”" => '"', "–" => "-", "—" => "-" }.freeze

    Result = Data.define(:items, :rejections, :warnings)

    def self.call(raw:, notes:)
      new(raw: raw, notes: notes).call
    end

    def initialize(raw:, notes:)
      @raw = raw
      @notes = notes.to_s
      @normalized_notes = normalize(@notes)
    end

    def call
      entries = parse_entries
      entries.each_with_index { |entry, index| check_types!(entry, index) }

      items = []
      rejections = []
      warnings = []
      seen = Set.new

      entries.each_with_index do |entry, index|
        description = clean(entry["description"]).squish
        quote = clean(entry["source_quote"]).strip

        reason =
          if description.empty? then "blank_description"
          elsif description.length > DESCRIPTION_MAX_LENGTH then "description_too_long"
          elsif quote.empty? || quote.length > QUOTE_MAX_LENGTH || !quote_in_notes?(quote) then "unsupported_source_quote"
          elsif quote.scan(/[[:alnum:]]+/).size < MIN_QUOTE_WORDS then "source_quote_too_short"
          elsif !seen.add?([ description.downcase, normalize(quote) ]) then "duplicate"
          end
        if reason
          rejections << { index: index, reason: reason }
          next
        end

        owner = grounded_owner(entry["owner"], quote, index, warnings)
        due_date = grounded_due_date(entry["due_date"], quote, index, warnings)
        items << { description: description, owner: owner, due_date: due_date, source_quote: quote }
      end

      Result.new(items: items, rejections: rejections, warnings: warnings)
    end

    private

    def parse_entries
      data = JSON.parse(@raw.to_s)
      unless data.is_a?(Hash) && data.keys == [ "action_items" ] && data["action_items"].is_a?(Array)
        raise InvalidResponse.new(:wrong_shape, "The AI response did not contain an action_items list.")
      end
      if data["action_items"].size > MAX_ITEMS
        raise InvalidResponse.new(:too_many_items, "The AI response contained more than #{MAX_ITEMS} items.")
      end

      data["action_items"]
    rescue JSON::ParserError
      raise InvalidResponse.new(:not_json, "The AI response was not valid JSON.")
    end

    def check_types!(entry, index)
      unless entry.is_a?(Hash) && entry.keys.sort == ITEM_KEYS.sort
        raise InvalidResponse.new(:wrong_item_shape, "Item #{index} does not have exactly #{ITEM_KEYS.join(', ')}.")
      end

      valid = entry["description"].is_a?(String) &&
        entry["source_quote"].is_a?(String) &&
        (entry["owner"].nil? || entry["owner"].is_a?(String)) &&
        (entry["due_date"].nil? || entry["due_date"].is_a?(String))
      raise InvalidResponse.new(:wrong_field_type, "Item #{index} has a field of the wrong type.") unless valid
    end

    # The owner must be named in the item's own quote. A name found elsewhere in
    # the notes may belong to a different or conflicting assignment, and the
    # spec prefers an empty owner to a guessed one.
    def grounded_owner(value, quote, index, warnings)
      owner = clean(value).squish
      return nil if owner.empty?

      if owner.length > OWNER_MAX_LENGTH || !normalize(quote).match?(/(?<![[:alnum:]])#{Regexp.escape(owner)}(?![[:alnum:]])/i)
        warnings << { index: index, field: "owner", reason: "owner_not_in_quote" }
        return nil
      end
      owner
    end

    # The due date must be written as an explicit calendar date in the item's own quote.
    def grounded_due_date(value, quote, index, warnings)
      text = clean(value).strip
      return nil if text.empty?

      date = text.match?(ISO_DATE) ? safe_date(text) : nil
      if date.nil?
        warnings << { index: index, field: "due_date", reason: "due_date_invalid" }
        return nil
      end
      unless ExplicitDates.in(quote).include?(date)
        warnings << { index: index, field: "due_date", reason: "due_date_not_in_quote" }
        return nil
      end
      date
    end

    def safe_date(text)
      Date.iso8601(text)
    rescue Date::Error
      nil
    end

    # The quote must appear in the notes starting and ending on word boundaries,
    # so a fragment such as "a" or "aya will send" does not count as support.
    def quote_in_notes?(quote)
      whole_word_occurrence?(@notes, quote) || whole_word_occurrence?(@normalized_notes, normalize(quote))
    end

    def whole_word_occurrence?(text, fragment)
      return false if fragment.empty?

      start = 0
      while (position = text.index(fragment, start))
        before = position.zero? ? "" : text[position - 1]
        after = text[position + fragment.length].to_s
        return true unless word_character?(before) && word_character?(fragment[0]) ||
                           word_character?(after) && word_character?(fragment[-1])

        start = position + 1
      end
      false
    end

    def word_character?(character)
      character.to_s.match?(/[[:alnum:]]/)
    end

    # Whitespace runs and typographic quotes/dashes are the only differences
    # tolerated between a quote and the notes.
    def normalize(text)
      text.to_s.gsub(/[‘’“”–—]/, TYPOGRAPHIC).squish
    end

    def clean(value)
      value.to_s.gsub(CONTROL_CHARACTERS, "")
    end
  end
end
