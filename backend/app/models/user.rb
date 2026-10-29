class User < ApplicationRecord
  belongs_to :organization

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def self.authenticate_token(token)
    return nil if token.blank?

    find_by(api_token_digest: digest(token))
  end

  # Development-only sign-in: issues a fresh random bearer token and stores
  # only its digest. Issuing a new token invalidates the previous one.
  def issue_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(api_token_digest: self.class.digest(token))
    token
  end
end
