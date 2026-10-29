module Ai
  module ProviderFactory
    module_function

    # AI_PROVIDER selects the adapter: "fake" (default, no secrets) or "anthropic".
    # Tests may set Rails.application.config.x.ai_provider_override.
    def build(name = ENV.fetch("AI_PROVIDER", "fake"))
      override = Rails.application.config.x.ai_provider_override
      return override if override

      case name.to_s
      when "fake" then Providers::Fake.new
      when "anthropic" then Providers::Claude.new
      else
        Rails.logger.error("[ai] unknown AI_PROVIDER #{name.inspect}; expected \"fake\" or \"anthropic\"")
        raise ProviderError.new("provider_misconfigured", "The server's AI provider setting is not supported.", retryable: false)
      end
    end
  end
end
