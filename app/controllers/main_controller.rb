class MainController < ApplicationController
  before_action :authenticate_user!

  def index
    if params['generate_new_key'].present?
      LtiKey.create key: "key_#{generate_random_string 10}", secret: generate_random_string(30)
    end
    @keys = LtiKey.all
  end

  private

  def generate_random_string(size)
    o = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
    (0...size).map { o[rand(o.length)] }.join
  end
end
