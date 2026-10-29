module Api
  module V1
    class ActionItemsController < ApplicationController
      STATUS_FILTERS = %w[all open completed].freeze

      def index
        status = params.fetch(:status, "all")
        unless STATUS_FILTERS.include?(status)
          return render_error(status: :bad_request, code: "bad_request",
                              message: "status must be one of #{STATUS_FILTERS.join(', ')}.")
        end

        items = current_organization.action_items.includes(:meeting, :suggestion, :accepted_by)
        items = items.incomplete if status == "open"
        items = items.completed if status == "completed"
        items = items.order(Arel.sql("action_items.completed_at IS NOT NULL"),
                            Arel.sql("action_items.due_date ASC NULLS LAST"),
                            created_at: :desc, id: :desc)

        render json: { action_items: items.map { |item| ApiJson.action_item(item) } }
      end

      def update
        item = current_organization.action_items.find(params[:id])
        completed = params.require(:action_item)[:completed]
        unless [ true, false ].include?(completed)
          return render_error(status: :bad_request, code: "bad_request", message: "completed must be true or false.")
        end

        item.with_lock do
          item.update!(completed_at: completed ? (item.completed_at || Time.current) : nil)
        end
        render json: { action_item: ApiJson.action_item(item) }
      end
    end
  end
end
