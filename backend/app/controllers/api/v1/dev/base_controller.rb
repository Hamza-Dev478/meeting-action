module Api
  module V1
    module Dev
      # Development-only authentication shortcut. Routes are drawn only when
      # Rails.env.local? (development/test); this guard is a second line of defence.
      class BaseController < ApplicationController
        skip_before_action :authenticate!
        before_action :ensure_local_environment!

        private

        def ensure_local_environment!
          head :not_found unless Rails.env.local?
        end
      end
    end
  end
end
