module TestHelpers
  module Auth
    # Issues a real token through the same code path the dev sign-in uses.
    def auth_headers_for(user)
      { "Authorization" => "Bearer #{user.issue_token!}" }
    end
  end

  module Json
    def json
      JSON.parse(response.body)
    end

    def error_code
      json.dig("error", "code")
    end
  end
end
