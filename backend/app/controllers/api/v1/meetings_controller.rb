module Api
  module V1
    class MeetingsController < ApplicationController
      include MeetingPayload

      def index
        meetings = current_organization.meetings.includes(:author).order(created_at: :desc, id: :desc)
        render json: { meetings: meetings.map { |meeting| ApiJson.meeting_summary(meeting) } }
      end

      def show
        render json: meeting_payload(current_organization.meetings.find(params[:id]))
      end

      def create
        meeting = current_organization.meetings.new(meeting_params.merge(author: current_user))
        meeting.save!
        render json: meeting_payload(meeting), status: :created
      end

      private

      # organization_id and author are never taken from the client.
      def meeting_params
        params.require(:meeting).permit(:title, :notes)
      end
    end
  end
end
