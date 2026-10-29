module Ai
  class ProviderTimeout < ProviderError
    def initialize(message = "The AI provider did not respond in time.")
      super("provider_timeout", message, retryable: true)
    end
  end
end
