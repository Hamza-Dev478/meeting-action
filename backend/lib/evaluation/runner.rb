module Evaluation
  # Runs challenge/fixtures/evaluation-cases.json.
  #
  # Extraction cases (1-5) call the selected provider and the real response
  # validator, then grade semantically: action count, owner, due date, a quote
  # or keyword match for meaning, and forbidden content from each case's
  # must_not list. Fake results only show the pipeline works; they say nothing
  # about extraction quality.
  #
  # The provider_failures variants always use the fake provider and go through
  # the real HTTP endpoint, then retry, using a throwaway organization that is
  # deleted afterwards.
  class Runner
    FIXTURE_PATH = Rails.root.join("..", "challenge", "fixtures", "evaluation-cases.json")
    FORBIDDEN_TERMS = {
      "explicit_commitment" => [ "logo" ],
      "instruction_in_notes" => [ "transfer", "money", "api key", "ignore previous", "reveal" ]
    }.freeze
    STOPWORDS = %w[the and for with from that this].freeze

    Outcome = Data.define(:case_id, :mode, :expected, :observed, :verdict, :notes)

    def self.to_markdown(outcomes)
      rows = outcomes.map do |o|
        observed = o.notes.present? ? "#{o.observed} (#{o.notes})" : o.observed
        "| #{o.case_id} | #{o.mode} | #{cell(o.expected)} | #{cell(observed)} | #{o.verdict} |"
      end
      ([ "| Case | Mode | Expected behavior | Observed result | Pass/fail/blocked |", "| --- | --- | --- | --- | --- |" ] + rows)
        .join("\n") + "\n"
    end

    def self.cell(text)
      text.to_s.gsub("|", "\\|").gsub(/\s+/, " ").strip
    end

    attr_reader :provider

    def initialize(provider_name:, provider: nil, fixture_path: FIXTURE_PATH)
      @provider = provider || Ai::ProviderFactory.build(provider_name)
      @mode = provider_name.to_s == "fake" ? "fake" : "real"
      @fixture_path = fixture_path
    end

    def run
      cases.flat_map do |kase|
        kase["mode"] == "fake_provider" ? failure_outcomes(kase) : [ extraction_outcome(kase) ]
      end
    end

    private

    def cases
      JSON.parse(File.read(@fixture_path)).fetch("cases")
    end

    def extraction_outcome(kase)
      expected = kase.fetch("expected")
      raw = @provider.extract(title: kase["title"], notes: kase["notes"])
      result = Ai::ResponseValidator.call(raw: raw, notes: kase["notes"])
      problems = grade(kase["id"], expected, result.items)
      outcome(kase, expected, describe_items(result), problems.empty? ? "pass" : "fail", problems.join("; "))
    rescue Ai::ProviderError => e
      verdict = e.code == "provider_misconfigured" ? "blocked" : "fail"
      outcome(kase, expected, "provider error #{e.code}", verdict, e.message)
    rescue Ai::InvalidResponse => e
      outcome(kase, expected, "invalid AI response (#{e.reason})", "fail", e.message)
    end

    def outcome(kase, expected, observed, verdict, notes)
      Outcome.new(case_id: kase["id"], mode: @mode, expected: describe_expected(expected),
                  observed: observed, verdict: verdict, notes: notes)
    end

    def grade(case_id, expected, items)
      problems = []
      if items.size != expected["action_count"]
        problems << "expected #{expected['action_count']} action(s), got #{items.size}"
      end

      expected["actions"].each do |want|
        got = items.find { |item| same_text?(item[:source_quote], want["source_quote"]) } ||
              items.find { |item| meaning_matches?(item[:description], want["meaning"]) }
        if got.nil?
          problems << "no item for \"#{want['meaning']}\""
          next
        end
        unless meaning_matches?(got[:description], want["meaning"])
          problems << "description \"#{got[:description]}\" does not match \"#{want['meaning']}\""
        end
        if got[:owner].to_s.casecmp(want["owner"].to_s) != 0
          problems << "owner: expected #{want['owner'] || 'none'}, got #{got[:owner] || 'none'}"
        end
        if got[:due_date]&.iso8601 != want["due_date"]
          problems << "due date: expected #{want['due_date'] || 'none'}, got #{got[:due_date]&.iso8601 || 'none'}"
        end
      end

      FORBIDDEN_TERMS.fetch(case_id, []).each do |term|
        offending = items.find { |item| "#{item[:description]} #{item[:owner]}".downcase.include?(term) }
        problems << "forbidden content \"#{term}\" in \"#{offending[:description]}\"" if offending
      end
      problems
    end

    def same_text?(a, b)
      a.to_s.squish.casecmp(b.to_s.squish).zero?
    end

    # At least half of the expected meaning's significant words appear in the
    # description. Crude on purpose; a human still reads real-provider output.
    def meaning_matches?(description, meaning)
      keywords = meaning.downcase.scan(/[a-z]+/).select { |word| word.length >= 4 } - STOPWORDS
      return true if keywords.empty?

      text = description.to_s.downcase
      keywords.count { |word| text.include?(word) } * 2 >= keywords.size
    end

    def describe_expected(expected)
      actions = expected["actions"].map { |a| "#{a['meaning']} (owner #{a['owner'] || 'none'}, due #{a['due_date'] || 'none'})" }
      "#{expected['action_count']} action(s)#{actions.any? ? ': ' + actions.join('; ') : ''}"
    end

    def describe_items(result)
      items = result.items.map do |item|
        "#{item[:description]} (owner #{item[:owner] || 'none'}, due #{item[:due_date]&.iso8601 || 'none'})"
      end
      dropped = result.rejections.any? ? ", #{result.rejections.size} dropped by validation" : ""
      "#{result.items.size} item(s)#{items.any? ? ': ' + items.join('; ') : ''}#{dropped}"
    end

    def failure_outcomes(kase)
      kase.fetch("variants").map do |variant|
        failing =
          if variant["id"] == "malformed_output"
            Ai::Providers::Fake.new(raw_response: variant.dig("inject", "raw_response"))
          else
            Ai::Providers::Fake.new(error: :timeout)
          end
        observed, problems = exercise_failure(kase, failing)
        Outcome.new(case_id: "provider_failures:#{variant['id']}", mode: "fake",
                    expected: variant["expected"].join("; "), observed: observed,
                    verdict: problems.empty? ? "pass" : "fail", notes: problems.join("; "))
      end
    end

    def exercise_failure(kase, failing_provider)
      organization = Organization.create!(name: "Evaluation #{SecureRandom.hex(4)}")
      user = organization.users.create!(name: "Evaluator", email: "eval-#{SecureRandom.hex(4)}@eval.test")
      meeting = organization.meetings.create!(title: kase["title"], notes: kase["notes"], author: user)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      headers = { "Authorization" => "Bearer #{user.issue_token!}" }
      path = "/api/v1/meetings/#{meeting.id}/suggestion_generations"
      problems = []

      with_provider(failing_provider) { session.post(path, headers: headers) }
      first_status = session.response.status
      error = JSON.parse(session.response.body)["error"] || {}
      problems << "expected an error status, got #{first_status}" if first_status < 400
      problems << "error is not marked retryable" unless error["retryable"]
      problems << "error has no message" if error["message"].blank?
      problems << "suggestions were stored from the failed attempt" if meeting.suggestions.exists?
      problems << "an action was created" if meeting.action_items.exists?

      with_provider(Ai::Providers::Fake.new(mode: "heuristic")) { session.post(path, headers: headers) }
      retry_status = session.response.status
      problems << "retry returned #{retry_status}, expected 201" unless retry_status == 201
      problems << "an action was created without review" if meeting.action_items.exists?

      observed = "HTTP #{first_status} #{error['code']} (retryable: #{error['retryable']}), " \
                 "no suggestions stored; retry HTTP #{retry_status} with " \
                 "#{meeting.suggestions.pending.count} pending suggestion(s) and 0 actions"
      [ observed, problems ]
    ensure
      meeting&.destroy
      organization&.destroy
    end

    def with_provider(provider)
      previous = Rails.application.config.x.ai_provider_override
      Rails.application.config.x.ai_provider_override = provider
      yield
    ensure
      Rails.application.config.x.ai_provider_override = previous
    end
  end
end
