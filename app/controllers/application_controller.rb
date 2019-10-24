class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  before_action :cors_set_access_control_headers

  def cors_preflight_check
    if request.method == 'OPTIONS'
      cors_set_access_control_headers
      render plain: ''
    end
  end

  protected

  def cors_set_access_control_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, PATCH, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, Token, Auth-Token, Email, X-User-Token, X-User-Email, Locale'
    response.headers['Access-Control-Max-Age'] = '1728000'
    response.headers['Access-Control-Expose-Headers'] = 'Exported-Filename'
  end
end
