module Api
  module V1
    module Dev
      class UsersController < BaseController
        def index
          users = User.includes(:organization).order(:organization_id, :name)
          render json: { users: users.map { |user| ApiJson.user(user) } }
        end
      end
    end
  end
end
