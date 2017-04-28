class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_one :oauth_token

  def get_tokens
    access_token = nil
    refresh_token = nil
    oauth_tokens = self.oauth_token
    if oauth_tokens.present?
      access_token = oauth_tokens.access_token
      refresh_token = oauth_tokens.refresh_token
    end
    [access_token, refresh_token]
  end
end
