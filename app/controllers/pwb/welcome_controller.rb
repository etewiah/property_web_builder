require_dependency 'pwb/application_controller'

module Pwb
  class WelcomeController < ApplicationController
    # GET /welcomes
    def index
      @carousel_items = Content.where(tag: 'landing-carousel')
      # .includes(:content_photos, :translations)
      @content_area_cols = Content.where(tag: 'content-area-cols').order('sort_order')
      @about_us = Content.find_by_key('aboutUs')
      @properties_for_sale = Prop.for_sale.visible.order('highlighted DESC').limit 9
    end
  end
end
