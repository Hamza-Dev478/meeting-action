module Ai
  module Providers
    # Real adapter: Anthropic Messages API through the official Ruby SDK, with
    # structured outputs constraining the reply to Ai::Prompt::SCHEMA. The
    # reply is still treated as untrusted and validated by Ai::ResponseValidator.
    class Claude
      DEFAULT_MODEL = "claude-opus-5-5"
      DEFAULT_EFFORT = "medium"
      DEFAULT_TIMEOUT_SECONDS = 25
      MAX_TOKENS = 16_000
      # Server-side fallback: a safety-classifier refusal is retried on the model
      # Anthropic recommends for that category instead of failing outright.
      FALLBACK_BETA = "server-side-fallback-2026-07-01"

      attr_reader :model

      def initialize(
        api_key: ENV["ANTHROPIC_API_KEY"],
        model: ENV.fetch("ANTHROPIC_MODEL", DEFAULT_MODEL),
        effort: ENV.fetch("ANTHROPIC_EFFORT", DEFAULT_EFFORT),
        timeout: ENV.fetch("ANTHROPIC_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS).to_f,
        client: nil
      )
        @api_key = api_key.presence
        @model = model
        @effort = effort
        @timeout = timeout
        @client = client
      end

      def name = "anthropic"

      def extract(title:, notes:)
        message = client.beta.messages.create(
          model: model,
          max_tokens: MAX_TOKENS,
          system_: Prompt::SYSTEM,
          messages: [ { role: "user", content: Prompt.user_content(title: title, notes: notes) } ],
          output_config: { effort: @effort, format: { type: "json_schema", schema: Prompt::SCHEMA } },
          fallbacks: :default,
          betas: [ FALLBACK_BETA ]
        )
        text_from(message)
      rescue ::Anthropic::Errors::APITimeoutError
        raise ProviderTimeout
      rescue ::Anthropic::Errors::AuthenticationError, ::Anthropic::Errors::PermissionDeniedError
        raise ProviderError.new("provider_misconfigured", "The AI provider rejected the server's credentials.", retryable: false)
      rescue ::Anthropic::Errors::BadRequestError, ::Anthropic::Errors::NotFoundError, ::Anthropic::Errors::UnprocessableEntityError => e
        Rails.logger.error("[ai] anthropic rejected request: #{e.message}")
        raise ProviderError.new("provider_rejected_request", "The AI provider rejected the request.", retryable: false)
      rescue ::Anthropic::Errors::RateLimitError
        raise ProviderError.new("provider_rate_limited", "The AI provider is busy. Try again shortly.")
      rescue ::Anthropic::Errors::APIStatusError
        raise ProviderError.new("provider_unavailable", "The AI provider is temporarily unavailable.")
      rescue ::Anthropic::Errors::APIConnectionError
        raise ProviderError.new("provider_unreachable", "The server could not reach the AI provider.")
      end

      private

      def client
        if @client.nil? && @api_key.nil?
          raise ProviderError.new("provider_misconfigured", "ANTHROPIC_API_KEY is not set on the server.", retryable: false)
        end

        # One SDK retry on 408/409/429/5xx/connection errors; the user can retry after that.
        @client ||= ::Anthropic::Client.new(api_key: @api_key, timeout: @timeout, max_retries: 1)
      end

      def text_from(message)
        case message.stop_reason&.to_sym
        when :refusal
          raise ProviderError.new("provider_refused", "The AI provider declined to process these notes.", retryable: false)
        when :max_tokens
          raise ProviderError.new("provider_truncated", "The AI response was cut off. Try again.")
        end

        message.content.select { |block| block.type.to_sym == :text }.map(&:text).join
      end
    end
  end
end
