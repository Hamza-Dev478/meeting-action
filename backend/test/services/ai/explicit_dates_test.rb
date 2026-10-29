require "test_helper"

class Ai::ExplicitDatesTest < ActiveSupport::TestCase
  test "finds ISO, year-first slash and month-name calendar dates" do
    text = "Due 2027-02-12, then 2027/3/4, then March 5th, 2027 and 6 Apr 2027."

    assert_equal [ Date.new(2027, 2, 12), Date.new(2027, 3, 4), Date.new(2027, 3, 5), Date.new(2027, 4, 6) ],
                 Ai::ExplicitDates.in(text).sort
  end

  test "ignores relative, year-less, ambiguous and impossible dates" do
    text = "next Friday, Feb 12, 03/04/2027, 2027-02-30, tomorrow"

    assert_empty Ai::ExplicitDates.in(text)
  end
end
