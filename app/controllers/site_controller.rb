class SiteController < ApplicationController

  def params
    @params ||= super.permit! # FIXME: Add support for strong params
  end

  # Raise exception, mostly for confirming that exception_notification works
  def omfg
    raise ArgumentError, "OMFG"
  end

  # Render something to help benchmark stack without the views
  def hello
    render :plain => "hello"
  end

  def index
    redirect_to(events_path(:format => params[:format]))
  end
  
  # Displays the about page.
  def about; end

  def opensearch
    respond_to do |format|
      format.xml { render :content_type => 'application/opensearchdescription+xml' }
    end
  end
end
