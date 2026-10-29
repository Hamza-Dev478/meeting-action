# Runs one synchronous suggestion generation for a meeting.
#
# Lifecycle: a `running` generation row is committed first (the partial unique
# index allows one per meeting), the provider is called outside any database
# transaction, the reply is validated, and only then are suggestions written in
# a short transaction. Failures mark the row `failed` and re-raise so the API
# can tell the client whether retrying makes sense. Existing suggestions are
# untouched by a failed run.
class SuggestionGenerator
  class InProgress < StandardError; end

  # Any other failure. The run is already marked failed and nothing was stored,
  # so the client can safely try again.
  class UnexpectedError < StandardError; end

  def initialize(provider:)
    @provider = provider
  end

  def call(meeting:, user:)
    generation = start!(meeting, user)
    raw = nil

    begin
      raw = @provider.extract(title: meeting.title, notes: meeting.notes)
      result = Ai::ResponseValidator.call(raw: raw, notes: meeting.notes)
      persist!(generation, meeting, result, raw)
    rescue Ai::ProviderError => e
      generation.mark_failed!(code: e.code, message: e.message)
      raise
    rescue Ai::InvalidResponse => e
      Rails.logger.warn("[ai] generation #{generation.id} invalid response (#{e.reason}): #{e.message}")
      generation.mark_failed!(code: "invalid_ai_response", message: e.message, raw_response: raw)
      raise
    rescue InProgress
      # The row was already closed as stale by a newer request; keep its status.
      raise
    rescue StandardError => e
      Rails.logger.error("[ai] generation #{generation.id} failed unexpectedly: #{e.class}: #{e.message}\n" \
                         "#{Array(e.backtrace).first(10).join("\n")}")
      generation.mark_failed!(code: "internal_error", message: "Unexpected error while generating suggestions.", raw_response: raw)
      raise UnexpectedError, "Unexpected error while generating suggestions."
    end
  end

  private

  def start!(meeting, user)
    meeting.suggestion_generations.stale.find_each do |abandoned|
      abandoned.mark_failed!(code: "stale", message: "The generation did not finish in time.")
    end

    meeting.suggestion_generations.create!(
      requested_by: user,
      status: :running,
      provider: @provider.name,
      model: @provider.model,
      prompt_version: Ai::Prompt::VERSION,
      started_at: Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    raise InProgress
  end

  def persist!(generation, meeting, result, raw)
    ActiveRecord::Base.transaction do
      generation.lock!
      # A run that was marked stale while the provider was still answering
      # must not overwrite the newer run's suggestions.
      raise InProgress unless generation.running?

      meeting.suggestions.pending.update_all(status: "superseded", updated_at: Time.current)
      result.items.each_with_index do |item, position|
        meeting.suggestions.create!(item.merge(suggestion_generation: generation, position: position))
      end

      generation.update!(
        status: :succeeded,
        suggestion_count: result.items.size,
        rejected_count: result.rejections.size,
        validation_report: { rejections: result.rejections, warnings: result.warnings },
        raw_response: raw.to_s.truncate(SuggestionGeneration::RAW_RESPONSE_LIMIT),
        finished_at: Time.current
      )
    end
    generation
  end
end
