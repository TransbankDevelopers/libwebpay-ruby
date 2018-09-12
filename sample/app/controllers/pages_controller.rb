class ApplicationController < ActionController::Base
  protect_from_forgery
end

class PagesController < ApplicationController

  protect_from_forgery except: :index
  skip_before_action :verify_authenticity_token

#Index
  def index
  end

  #Mostrar paginas

  def show
    render template: "pages/#{params[:page]}"
  end

  def tbknormal
    #render text: "tbknormal"
    #render template: "pages/#{params[:page]}"
  end

  def tbkoneclick
    #render text: "tbkoneclick"
    #render template: "pages/tbkoneclick"
  end


end
