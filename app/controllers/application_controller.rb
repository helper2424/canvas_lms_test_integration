class ApplicationController < ActionController::Base
  before_action :allow_origin

  def allow_origin
    headers['X-Frame-Options'] = 'ALLOWALL'
  end
end
