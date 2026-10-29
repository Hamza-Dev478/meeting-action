ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# A developer's backend/.env must not change test behaviour.
ENV.delete("FAKE_AI_MODE")
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Each worker process gets its own fake-provider mode file so a test that
    # injects a failure mode cannot leak into tests running in another process.
    Rails.application.config.x.fake_ai_mode_file = Rails.root.join("tmp/fake_ai_mode-test")
    parallelize_setup do |worker|
      Rails.application.config.x.fake_ai_mode_file = Rails.root.join("tmp/fake_ai_mode-test-#{worker}")
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include TestHelpers::Auth
  end
end

class ActionDispatch::IntegrationTest
  include TestHelpers::Json
end
