module Ai
  # Finds unambiguous calendar dates written in text. Used to check that a
  # model-supplied due date is actually stated in the notes. Year-less dates,
  # day/month-ambiguous forms (03/04/2027) and relative dates are ignored on
  # purpose: they need interpretation, which this exercise forbids.
  module ExplicitDates
    MONTHS = {
      "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4, "may" => 5, "jun" => 6,
      "jul" => 7, "aug" => 8, "sep" => 9, "sept" => 9, "oct" => 10, "nov" => 11, "dec" => 12
    }.freeze
    MONTH_NAME = "(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sept?(?:ember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"
    ORDINAL = "(?:st|nd|rd|th)?"

    ISO = /\b(\d{4})-(\d{2})-(\d{2})\b/
    YEAR_FIRST_SLASH = %r{\b(\d{4})/(\d{1,2})/(\d{1,2})\b}
    MONTH_DAY_YEAR = /\b#{MONTH_NAME}\.?\s+(\d{1,2})#{ORDINAL},?\s+(\d{4})\b/i
    DAY_MONTH_YEAR = /\b(\d{1,2})#{ORDINAL}\s+(?:of\s+)?#{MONTH_NAME}\.?,?\s+(\d{4})\b/i

    module_function

    def in(text)
      text = text.to_s
      dates = []
      text.scan(ISO) { |y, m, d| dates << build(y, m, d) }
      text.scan(YEAR_FIRST_SLASH) { |y, m, d| dates << build(y, m, d) }
      text.scan(MONTH_DAY_YEAR) { |month, d, y| dates << build(y, month_number(month), d) }
      text.scan(DAY_MONTH_YEAR) { |d, month, y| dates << build(y, month_number(month), d) }
      dates.compact.uniq
    end

    def month_number(name)
      MONTHS.fetch(name.downcase[0, 4] == "sept" ? "sept" : name.downcase[0, 3])
    end

    def build(year, month, day)
      Date.new(year.to_i, month.to_i, day.to_i)
    rescue Date::Error
      nil
    end
  end
end
