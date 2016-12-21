require_dependency 'pwb/application_controller'

module Pwb
  class WelcomeController < ApplicationController

    before_filter :set_theme_path

    def set_theme_path
      prepend_view_path "#{Pwb::Engine.root}/app/themes/chic/views/"
      # below allows themes installed in Rails app consuming Pwb to work
      prepend_view_path "#{Rails.root}/app/themes/default/views/"
    end

    def index
      @carousel_items = Content.where(tag: 'landing-carousel')
      @carousel_speed = 3000
      # .includes(:content_photos, :translations)
      @content_area_cols = Content.where(tag: 'content-area-cols').order('sort_order')
      @about_us = Content.find_by_key('aboutUs')
      @properties_for_sale = Prop.for_sale.visible.order('highlighted DESC').limit 9
      @properties_for_rent = Prop.for_rent.visible.order('highlighted DESC').limit 9

      return render "welcome/index"

    end
  end
end
