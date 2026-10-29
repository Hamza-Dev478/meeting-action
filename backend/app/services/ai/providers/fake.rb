module Ai
  module Providers
    # Deterministic stand-in for a real model. It recognises two sentence
    # shapes ("<Name> will <task> by <YYYY-MM-DD>." and "Decision: <task>.")
    # so local review works without credentials. Its output says nothing about
    # real extraction quality.
    #
    # Failure modes can be injected per instance (tests) or for the running
    # server via tmp/fake_ai_mode (`bin/rails "ai:fake_mode[timeout_once]"`).
    class Fake
      MODES = %w[heuristic malformed timeout error slow].freeze
      MALFORMED_RESPONSE = "{this is not valid JSON".freeze

      COMMITMENT = /\A(?<owner>[A-Z][a-z]+) will (?<task>.+?) by (?<date>\d{4}-\d{2}-\d{2})\.?\z/
      DECISION = /\ADecision: (?<task>.+?)\.?\z/
      SENTENCE = /[^.!?\n]+[.!?]?/

      class << self
        def mode_file
          Rails.application.config.x.fake_ai_mode_file || Rails.root.join("tmp/fake_ai_mode")
        end

        def write_mode!(mode)
          base = mode.to_s.delete_suffix("_once")
          raise ArgumentError, "Unknown fake AI mode #{mode.inspect}. Use one of #{MODES.join(', ')} (optionally with _once)." unless MODES.include?(base)

          FileUtils.mkdir_p(File.dirname(mode_file))
          File.write(mode_file, mode.to_s)
        end

        def clear_mode!
          FileUtils.rm_f(mode_file)
        end

        # Reads the configured mode; a `_once` mode is consumed by this read.
        def consume_mode
          mode = File.exist?(mode_file) ? File.read(mode_file).strip : ENV.fetch("FAKE_AI_MODE", "heuristic")
          if mode.end_with?("_once")
            clear_mode!
            mode = mode.delete_suffix("_once")
          end
          MODES.include?(mode) ? mode : "heuristic"
        end
      end

      def initialize(raw_response: nil, error: nil, mode: nil, slow_seconds: ENV.fetch("FAKE_AI_SLOW_SECONDS", 5).to_f)
        @raw_response = raw_response
        @error = error
        @mode = mode
        @slow_seconds = slow_seconds
      end

      def name = "fake"

      def model = "fake-heuristic"

      def extract(title:, notes:)
        return @raw_response unless @raw_response.nil?

        case @error&.to_s || @mode || self.class.consume_mode
        when "malformed" then MALFORMED_RESPONSE
        when "timeout" then raise ProviderTimeout
        when "error" then raise ProviderError.new("provider_unavailable", "The AI provider is temporarily unavailable.")
        when "slow"
          sleep(@slow_seconds)
          heuristic(notes)
        else heuristic(notes)
        end
      end

      private

      def heuristic(notes)
        items = notes.to_s.scan(SENTENCE).map(&:strip).filter_map do |sentence|
          if (match = sentence.match(COMMITMENT))
            item(match[:task], match[:owner], match[:date], sentence)
          elsif (match = sentence.match(DECISION))
            item(match[:task], nil, nil, sentence)
          end
        end
        JSON.generate(action_items: items)
      end

      def item(task, owner, due_date, quote)
        { description: task.sub(/\A[a-z]/, &:upcase), owner: owner, due_date: due_date, source_quote: quote }
      end
    end
  end
end
