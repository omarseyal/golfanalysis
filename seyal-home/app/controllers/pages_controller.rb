class PagesController < ApplicationController
  def show
    @page = Page.current
  end
end
