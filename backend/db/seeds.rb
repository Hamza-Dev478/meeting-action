# Fictional, synthetic data only. Safe to run repeatedly: meetings that already exist are left alone.
# To reset the development database to exactly this data, run `bin/rails db:seed:replant`.
#
# Notes use the sentence shapes the fake AI provider recognises, "<Name> will <task> by <YYYY-MM-DD>."
# and "Decision: <task>.", mixed with discussion that must not become an action (no owner, no date,
# relative dates like "next Friday"). Dates are relative to the day you seed, so the Actions screen
# always has something overdue, due this week, due later, and done.
#
# Each meeting is in one of three states, to show the whole flow:
#   - reviewed: a past generation, with accepted actions (some completed) and maybe pending suggestions
#   - pending review: a past generation whose suggestions nobody has reviewed yet
#   - fresh: notes only, ready for "Generate suggestions"
#
# Development sign-in: the app's sign-in screen lists these users, or call
#   curl -X POST http://localhost:3000/api/v1/dev/session -H 'Content-Type: application/json' -d '{"email":"maya@acme.test"}'

today = Date.current

# `review:` nil = not generated yet, :pending = suggested but not reviewed, :accepted, :completed.
# `edited:` is the reviewer's wording when it differs from the suggestion.
seed = {
  "Acme Robotics" => {
    users: [
      { name: "Maya Chen", email: "maya@acme.test" },
      { name: "Leo Park", email: "leo@acme.test" }
    ],
    meetings: [
      {
        title: "Q1 launch planning",
        author: "maya@acme.test",
        days_ago: 18,
        before: "Agenda: launch scope, demo logistics and open risks.",
        items: [
          { owner: "Maya", task: "send the launch checklist to the leadership team", due: -4, review: :accepted },
          { owner: "Leo", task: "book the demo hall for launch day", due: 3, review: :accepted },
          { task: "ship the warehouse picker with the new gripper", review: :completed }
        ],
        after: "We talked about a new logo but nothing was decided. Someone should look at pricing again next Friday."
      },
      {
        title: "Northwind pilot feedback review",
        author: "leo@acme.test",
        days_ago: 11,
        before: "Northwind has run two picker robots in their warehouse for three weeks.",
        items: [
          { owner: "Leo", task: "summarise the pilot feedback for engineering", due: -8, review: :completed },
          {
            owner: "Maya", task: "reduce false battery alerts on the picker", due: 12, review: :accepted,
            edited: "Reduce false low-battery alerts on the picker dashboard"
          },
          { task: "hold a weekly check-in with the Northwind operations lead", review: :pending }
        ],
        after: "The customer liked the pick speed but found the dashboard noisy."
      },
      {
        title: "Controls engineer hiring sync",
        author: "maya@acme.test",
        days_ago: 7,
        before: "We reviewed three candidate profiles for the controls engineer role. " \
                "Everyone agreed the bar is high and the take-home task works well. " \
                "We will revisit after the robotics job fair.",
        items: []
      },
      {
        title: "Robot arm safety review",
        author: "maya@acme.test",
        days_ago: 4,
        before: "Safety review of the six-axis arm before the customer demo.",
        items: [
          { owner: "Leo", task: "update the emergency-stop wiring diagram", due: 6 },
          { owner: "Maya", task: "schedule the external safety audit", due: 20 },
          { task: "pause night-shift testing until the audit is complete" }
        ],
        after: "Leo mentioned the wrist torque sensor might need replacing, but nobody took it on."
      },
      {
        title: "Weekly engineering sync",
        author: "leo@acme.test",
        days_ago: 1,
        before: "Sprint 14 review and plan.",
        items: [
          { owner: "Leo", task: "review the motor driver pull request", due: 1 },
          { owner: "Maya", task: "publish the sprint notes", due: 2 },
          { task: "move the daily stand-up to half past nine" }
        ],
        after: "The simulator flakiness came up again; we will look at it when someone has time."
      }
    ]
  },
  "Globex Studios" => {
    users: [
      { name: "Nina Patel", email: "nina@globex.test" },
      { name: "Omar Haddad", email: "omar@globex.test" }
    ],
    meetings: [
      {
        title: "Brand refresh kickoff",
        author: "nina@globex.test",
        days_ago: 15,
        before: "Kickoff with the Lumen Coffee team for their brand refresh.",
        items: [
          { owner: "Nina", task: "send the brand questionnaire to the client", due: -6, review: :completed },
          {
            owner: "Omar", task: "draft three logo directions", due: -1, review: :accepted,
            edited: "Draft three logo directions for the client review"
          },
          { task: "refresh the style guide before any new campaign work", review: :accepted }
        ],
        after: "The client mentioned packaging, but it is out of scope for now."
      },
      {
        title: "Spring campaign storyboard review",
        author: "omar@globex.test",
        days_ago: 6,
        before: "First pass on the spring campaign storyboards.",
        items: [
          { owner: "Nina", task: "share the revised storyboard with the client", due: 4, review: :pending },
          { owner: "Omar", task: "book the voice-over studio", due: 9, review: :pending }
        ],
        after: "We liked the second concept best; the music choice is still open."
      },
      {
        title: "Studio operations weekly",
        author: "nina@globex.test",
        days_ago: 2,
        before: "Studio housekeeping and tooling.",
        items: [
          { owner: "Nina", task: "renew the font licences", due: 5 },
          { owner: "Omar", task: "archive last year's project files", due: 14 },
          { task: "move client reviews to Thursdays" }
        ],
        after: "Omar asked whether the archive should move to the cloud; no decision was made."
      }
    ]
  }
}

sentence = lambda do |item|
  if item[:owner]
    "#{item[:owner]} will #{item[:task]} by #{(today + item[:due]).iso8601}."
  else
    "Decision: #{item[:task]}."
  end
end

ActiveRecord::Base.transaction do
  seed.each do |org_name, data|
    organization = Organization.find_or_create_by!(name: org_name)

    users = data[:users].to_h do |attrs|
      user = User.find_or_create_by!(email: attrs[:email]) do |new_user|
        new_user.name = attrs[:name]
        new_user.organization = organization
      end
      [ attrs[:email], user ]
    end

    data[:meetings].each do |attrs|
      next if organization.meetings.exists?(title: attrs[:title])

      held_at = Time.zone.parse("#{today - attrs[:days_ago]} 10:00")
      author = users.fetch(attrs[:author])
      quotes = attrs[:items].map { |item| sentence.call(item) }
      meeting = organization.meetings.create!(
        title: attrs[:title],
        notes: [ attrs[:before], *quotes, attrs[:after] ].compact.join(" "),
        author: author,
        created_at: held_at,
        updated_at: held_at
      )
      next if attrs[:items].none? { |item| item[:review] }

      generated_at = held_at + 5.minutes
      generation = meeting.suggestion_generations.create!(
        requested_by: author,
        status: :succeeded,
        provider: "fake",
        prompt_version: Ai::Prompt::VERSION,
        suggestion_count: attrs[:items].size,
        started_at: generated_at,
        finished_at: generated_at + 2.seconds
      )

      attrs[:items].zip(quotes).each_with_index do |(item, quote), position|
        description = item[:task].sub(/\A./, &:upcase)
        due_date = item[:due] && today + item[:due]
        accepted = item[:review].in?(%i[accepted completed])
        suggestion = meeting.suggestions.create!(
          suggestion_generation: generation,
          status: accepted ? :accepted : :pending,
          description: description,
          owner: item[:owner],
          due_date: due_date,
          source_quote: quote,
          position: position
        )
        next unless accepted

        meeting.action_items.create!(
          suggestion: suggestion,
          accepted_by: author,
          description: item[:edited] || description,
          owner: item[:owner],
          due_date: due_date,
          source_quote: quote,
          completed_at: item[:review] == :completed ? [ held_at + 2.days, Time.current ].min : nil,
          created_at: generated_at + 10.minutes
        )
      end
    end
  end
end

puts "Seeded #{Organization.count} organizations, #{User.count} users, #{Meeting.count} meetings, " \
     "#{ActionItem.count} actions."
User.includes(:organization).order(:organization_id, :name).each do |user|
  puts "  #{user.organization.name.ljust(16)} #{user.name.ljust(12)} #{user.email}"
end
