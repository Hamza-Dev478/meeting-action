require "test_helper"

# Runs outside a wrapping transaction so each thread has its own real database
# connection and transaction, like concurrent Puma requests would.
class ConcurrentAcceptanceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  THREADS = 4

  # Test-only gate: holds each thread just before it builds the action until
  # every thread has arrived (or 0.5s passes). Without the row lock all threads
  # reach the gate together and race to INSERT, so a missing invariant fails
  # deterministically. With the lock only one thread can be inside at a time,
  # so the gate simply times out and the test still passes.
  module InsertGate
    mattr_accessor :barrier

    private

    def build_item
      InsertGate.barrier&.wait(0.5)
      super
    end
  end
  SuggestionAcceptance.prepend(InsertGate)

  setup do
    # Lazy autoloading in test mode would otherwise serialize the threads.
    Rails.application.eager_load!

    @organization = Organization.create!(name: "Concurrency Co #{SecureRandom.hex(4)}")
    @user = @organization.users.create!(name: "Ari", email: "ari-#{SecureRandom.hex(4)}@concurrency.test")
    @meeting = @organization.meetings.create!(title: "Release", author: @user,
                                              notes: "Ari will prepare the release summary by 2027-03-10.")
    generation = @meeting.suggestion_generations.create!(requested_by: @user, provider: "fake", prompt_version: "test",
                                                         status: :succeeded, started_at: Time.current)
    @suggestion = @meeting.suggestions.create!(suggestion_generation: generation, description: "Prepare the release summary",
                                               owner: "Ari", source_quote: "Ari will prepare the release summary by 2027-03-10.")
    InsertGate.barrier = Concurrent::CyclicBarrier.new(THREADS)
  end

  teardown do
    InsertGate.barrier = nil
    ActionItem.where(meeting: @meeting).delete_all
    Suggestion.where(meeting: @meeting).delete_all
    SuggestionGeneration.where(meeting: @meeting).delete_all
    @meeting.delete
    @user.delete
    @organization.delete
  end

  test "simultaneous accepts of one suggestion create exactly one action" do
    start = Concurrent::CyclicBarrier.new(THREADS)

    results = Array.new(THREADS) do |n|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.wait
          SuggestionAcceptance.new(suggestion: Suggestion.find(@suggestion.id), user: @user,
                                   attrs: { description: "Attempt #{n}" }).call
        end
      end
    end.map(&:value)

    assert_equal 1, ActionItem.where(suggestion_id: @suggestion.id).count
    assert_equal 1, results.map { |result| result.action_item.id }.uniq.size
    assert_equal 1, results.count(&:created)
    assert @suggestion.reload.accepted?
  end
end
