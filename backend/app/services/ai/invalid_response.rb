module Ai
  # The provider answered, but the answer broke the response contract
  # (not JSON, wrong shape, wrong field types). Nothing from it is stored.
  class InvalidResponse < StandardError
    attr_reader :reason

    def initialize(reason, message)
      super(message)
      @reason = reason
    end
  end
end
