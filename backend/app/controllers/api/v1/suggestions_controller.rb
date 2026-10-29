module Api
  module V1
    class SuggestionsController < ApplicationController
      before_action :load_suggestion

      rescue_from SuggestionAcceptance::NotPending do |error|
        render_error(status: :conflict, code: "suggestion_not_pending", details: { status: error.status },
                     message: "This suggestion is #{error.status} and can no longer be changed. Refresh the meeting.")
      end

      # 201 when this request created the action, 200 when it already existed.
      def accept
        result = SuggestionAcceptance.new(suggestion: @suggestion, user: current_user, attrs: acceptance_params).call
        render json: { action_item: ApiJson.action_item(result.action_item), created: result.created },
               status: result.created ? :created : :ok
      end

      def dismiss
        @suggestion.with_lock do
          raise SuggestionAcceptance::NotPending, @suggestion.status unless @suggestion.pending? || @suggestion.dismissed?

          @suggestion.dismissed! unless @suggestion.dismissed?
        end
        render json: { suggestion: ApiJson.suggestion(@suggestion) }
      end

      private

      def load_suggestion
        @suggestion = current_organization.suggestions.find(params[:id])
      end

      def acceptance_params
        params.fetch(:action_item, {}).permit(:description, :owner, :due_date)
      end
    end
  end
end
