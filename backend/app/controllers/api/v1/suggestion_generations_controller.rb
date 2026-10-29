module Api
  module V1
    # Synchronous generation. If the client gives up (timeout, app closed) the
    # request keeps running here and its result is stored; the client sees it
    # on the next GET /meetings/:id, and a retry meanwhile gets 409.
    class SuggestionGenerationsController < ApplicationController
      def create
        meeting = current_organization.meetings.find(params[:meeting_id])
        generation = SuggestionGenerator.new(provider: Ai::ProviderFactory.build).call(meeting: meeting, user: current_user)

        render status: :created, json: {
          generation: ApiJson.generation(generation),
          suggestions: generation.suggestions.order(:position).map { |s| ApiJson.suggestion(s) }
        }
      rescue SuggestionGenerator::InProgress
        render_error(status: :conflict, code: "generation_in_progress", retryable: true,
                     message: "Suggestions are already being generated for this meeting. Refresh in a moment.")
      rescue Ai::ProviderTimeout => e
        render_error(status: :gateway_timeout, code: e.code, message: e.message, retryable: true)
      rescue Ai::ProviderError => e
        render_error(status: :bad_gateway, code: e.code, message: e.message, retryable: e.retryable?)
      rescue Ai::InvalidResponse
        render_error(status: :bad_gateway, code: "invalid_ai_response", retryable: true,
                     message: "The AI returned a response the app could not use. Nothing was saved. Try again.")
      rescue SuggestionGenerator::UnexpectedError
        render_error(status: :internal_server_error, code: "internal_error", retryable: true,
                     message: "Something went wrong while generating suggestions. Nothing was saved. Try again.")
      end
    end
  end
end
