require_dependency 'pwb/application_controller'

module Pwb


  class ComfyController < ApplicationController
    # Comfy::Cms::BaseController

    # Authentication module must have `authenticate` method
    include ComfortableMexicanSofa.config.public_auth.to_s.constantize

    # Authorization module must have `authorize` method
    include ComfortableMexicanSofa.config.public_authorization.to_s.constantize

    before_action :load_cms_site
    # before_action :load_fixtures
    # before_action :load_cms_page,
    #   :authenticate,
    #   :authorize,
    #   :only => :show

    rescue_from ActiveRecord::RecordNotFound, :with => :page_not_found

    def show
      # byebug
      @content = Content.find_by_key("aboutUs")
      @page_title = I18n.t("aboutUs")

      # @agency = Agency.find_by_subdomain(request.subdomain.downcase)
      # @enquiry = Message.new
      # return render "/pwb/sections/about_us"
      # return render_page
      # byebug
      return render :cms_page => "/", :layout => "pwb/application"
      # return render @cms_page.content_cache
      # , layout: "application"

            # if false 
      #  # @cms_page.target_page.present?
      #   redirect_to @cms_page.target_page.url(:relative)
      # else
      #   respond_to do |format|
      #     format.html { render_page }
      #     format.json { render :json => @cms_page }
      #   end
      # end
    end

    def render_sitemap
      render
    end

    protected

    def load_cms_site
      @cms_site = ::Comfy::Cms::Site.first
    end

    def render_page(status = 200)
      if @cms_layout = @cms_page.layout
        # app_layout = (@cms_layout.app_layout.blank? || request.xhr?) ? false : @cms_layout.app_layout
        # byebug
        app_layout = "application"
        render  :inline       => @cms_page.content_cache,
          :layout       => app_layout,
          :status       => status,
          :content_type => mime_type
      else
        render :plain => I18n.t('comfy.cms.content.layout_not_found'), :status => 404
      end
    end

    # it's possible to control mimetype of a page by creating a `mime_type` field
    def mime_type
      mime_block = @cms_page.blocks.find_by_identifier(:mime_type)
      mime_block && mime_block.content || 'text/html'
    end

    def load_fixtures
      return unless ComfortableMexicanSofa.config.enable_fixtures
      ComfortableMexicanSofa::Fixture::Importer.new(@cms_site.identifier).import!
    end

    def load_cms_page
      @cms_page = @cms_site.pages.published.find_by_full_path!("/#{params[:cms_path]}")
    end

    def page_not_found
      @cms_page = @cms_site.pages.published.find_by_full_path!('/404')

      respond_to do |format|
        format.html { render_page(404) }
      end
    rescue ActiveRecord::RecordNotFound
      raise ActionController::RoutingError.new("Page Not Found at: \"#{params[:cms_path]}\"")
    end
  end

 
end
