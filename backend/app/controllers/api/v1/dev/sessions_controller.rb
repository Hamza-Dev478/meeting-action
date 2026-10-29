module Api
  module V1
    module Dev
      class SessionsController < BaseController
        def create
          user = User.includes(:organization).find_by!(email: params.require(:email).to_s.strip.downcase)
          render json: { token: user.issue_token!, user: ApiJson.user(user) }
        end
      end
    end
  end
end
