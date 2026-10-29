require "test_helper"

class Ai::ProviderFactoryTest < ActiveSupport::TestCase
  test "fake is the default provider and needs no secrets" do
    assert_instance_of Ai::Providers::Fake, Ai::ProviderFactory.build("fake")
  end

  test "anthropic builds the real adapter" do
    assert_instance_of Ai::Providers::Claude, Ai::ProviderFactory.build("anthropic")
  end

  test "unknown provider names are reported as a misconfigured provider" do
    error = assert_raises(Ai::ProviderError) { Ai::ProviderFactory.build("openai") }

    assert_equal "provider_misconfigured", error.code
    refute error.retryable?
  end
end
