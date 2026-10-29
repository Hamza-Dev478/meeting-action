module TestHelpers
  module ProviderOverride
    def use_provider(provider)
      Rails.application.config.x.ai_provider_override = provider
    end

    def self.included(base)
      base.teardown { Rails.application.config.x.ai_provider_override = nil }
    end
  end
end
