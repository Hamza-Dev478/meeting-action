module Ai
  # Raised by provider adapters. `code` is a stable machine-readable string that
  # is returned to clients; `retryable?` tells the client whether trying again
  # can help.
  class ProviderError < StandardError
    attr_reader :code

    def initialize(code, message, retryable: true)
      super(message)
      @code = code
      @retryable = retryable
    end

    def retryable?
      @retryable
    end
  end
end
