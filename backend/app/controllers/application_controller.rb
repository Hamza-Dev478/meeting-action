class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate!

  # Declared first so every more specific handler below takes precedence
  # (Rails checks rescue_from handlers from the last declared to the first).
  # Clients always get the JSON error format; details stay in the server log.
  rescue_from StandardError do |error|
    Rails.logger.error("[api] unhandled #{error.class}: #{error.message}\n#{Array(error.backtrace).first(15).join("\n")}")
    render_error(status: :internal_server_error, code: "internal_error",
                 message: "Something went wrong on the server. Try again later.")
  end

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_error(status: :bad_request, code: "bad_request", message: "The request body is not valid JSON.")
  end

  rescue_from ActiveRecord::RecordNotFound do
    render_error(status: :not_found, code: "not_found", message: "That record does not exist.")
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error(status: :bad_request, code: "bad_request", message: error.message)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_validation_error(error.record.errors)
  end

  private

  def authenticate!
    user = authenticate_with_http_token { |token, _options| User.authenticate_token(token) }
    if user
      Current.user = user
    else
      render_error(status: :unauthorized, code: "unauthorized", message: "Your session has expired. Sign in again.")
    end
  end

  def current_user
    Current.user
  end

  # Organization access is always derived from the authenticated user on the
  # server; clients never send an organization ID.
  def current_organization
    current_user.organization
  end

  def render_error(status:, code:, message:, retryable: false, details: nil)
    error = { code: code, message: message, retryable: retryable }
    error[:details] = details if details.present?
    render json: { error: error }, status: status
  end

  def render_validation_error(errors)
    render_error(
      status: :unprocessable_content,
      code: "validation_failed",
      message: errors.full_messages.to_sentence.presence || "The request is invalid.",
      details: errors.to_hash
    )
  end
end
