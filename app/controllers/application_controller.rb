# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '8813a7fec0bb4fbffd283a3868998eed'

  # Setup theme
  layout "application"

  before_filter :current_site
  before_filter :set_theme

protected

  def current_site
    @current_site = Site.find_by_domain!(request.host)
    @current_site.use!
  end

  #---[ Helpers ]---------------------------------------------------------

  # Returns a data structure used for telling the CSS menu which part of the
  # site the user is on. The structure's keys are the symbol names of resources
  # and their values are either "active" or nil.
  def link_class
    return @_link_class_cache ||= {
      :events => (( controller_name == 'events' ||
                    controller_name == 'sources' ||
                    controller_name == 'site')  && 'active'),
      :venues => (controller_name == 'venues'  && 'active'),
      :organizations => (controller_name == 'organizations' && 'active'),
    }
  end
  helper_method :link_class

  #---[ Misc ]------------------------------------------------------------

  # Set or append flash +message+ (e.g. "OMG!") to flash key with the name
  # +kind+ (e.g. :failure).
  def append_flash(kind, message)
    kind = kind.to_sym
    if leaf = flash[kind]
      flash[kind] = "#{leaf} #{message}"
    else
      flash[kind] = "#{message}"
    end
  end

  # find missing/nonnumeric ids in list and look them up/create them, setting id
  def create_missing_refs(list, model)
    list ||= []
    if list.is_a?(Array)
      list.map do |item|
        begin
          i = model.find(Integer(item))
        rescue ArgumentError, ActiveRecord::RecordNotFound
          i = model.find_or_create_by(name: item)
        end
        i[:id]
      end
    end
  end

  def set_theme
    prepend_view_path "themes/#{THEME_NAME}/views"
  end
end

# Make it possible to use helpers in controllers
# http://www.johnyerhot.com/2008/01/10/rails-using-helpers-in-you-controller/
class Helper
  include Singleton
  include ActionView::Helpers::UrlHelper # Provide: #link_to
  include ActionView::Helpers::TagHelper # Provide: #escape_once (which #link_to needs)
end
def help
  Helper.instance
end

# Return string with contents HTML escaped once.
def escape_once(*args)
  help.escape_once(*args)
end

def user_for_paper_trail
  user_signed_in? ? current_user.id : nil
end

def authenticate_admin
  redirect_to root_url unless current_user.try(:admin)
end

def venue_ref(event_hash, venue_name)
  if (event_hash && event_hash[:venue_id].present?)
    event_hash[:venue_id].to_i
  else
    venue_name
  end
end
