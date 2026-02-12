# frozen_string_literal: true

# SitemapsController generates XML sitemaps for each tenant website
# Includes properties, pages, and main site URLs
class SitemapsController < ActionController::Base
  include SubdomainTenant
  include SeoHelper
  helper_method :spp_live_url_for

  # Tenant is set automatically via SubdomainTenant concern

  def index
    @website = Pwb::Current.website
    return render_not_found unless @website

    @host = request.host_with_port
    @protocol = request.protocol

    # Get all published/visible content for this website
    # Fetch properties for sale and rent separately to avoid .select(&:for_sale) in view
    @properties_for_sale = fetch_properties.for_sale
    @properties_for_rent = fetch_properties.for_rent
    @pages = fetch_pages

    respond_to do |format|
      format.xml { render layout: false }
    end
  end

  private

  def fetch_properties
    # Use the materialized view for efficient querying
    # Note: title is computed from associated listings, not a column
    # Eager load photos with attachment blob for image sitemap
    # Pre-order photos by sort_order to avoid N+1 in view
    Pwb::ListedProperty
      .where(website_id: @website.id)
      .where(visible: true)
      .includes(prop_photos: { image_attachment: :blob })
      .order(updated_at: :desc)
  end

  def fetch_pages
    Pwb::Page
      .where(website_id: @website.id)
      .where(visible: true)
      .order(updated_at: :desc)
  end

  def render_not_found
    render plain: 'Website not found', status: :not_found
  end
end
