# frozen_string_literal: true

# SeoHelper provides centralized SEO meta tag generation
# Supports page titles, descriptions, Open Graph, Twitter Cards, and canonical URLs
#
# Usage in controllers:
#   set_seo(title: "Property Name", description: "...", image: url)
#
# Usage in views:
#   <%= seo_meta_tags %>
#
module SeoHelper
  # Store SEO data for the current request
  def set_seo(options = {})
    @seo_data ||= {}
    @seo_data.merge!(options)
  end

  # Get current SEO data with fallbacks
  def seo_data
    @seo_data || {}
  end

  # Generate the page title with site name
  def seo_title
    parts = []

    # Page-specific title
    if seo_data[:title].present?
      parts << seo_data[:title]
    elsif @page_title.present?
      parts << @page_title
    end

    # Site name
    site_name = current_website&.company_display_name.presence || current_website&.subdomain.presence || 'PropertyWebBuilder'
    parts << site_name if parts.empty? || seo_data[:include_site_name] != false

    parts.uniq.join(' | ')
  end

  # Get meta description with fallbacks
  def seo_description
    seo_data[:description].presence ||
      @meta_description.presence ||
      current_website&.default_meta_description.presence ||
      "Find your perfect property with #{current_website&.company_display_name || 'us'}"
  end

  # Get canonical URL
  def seo_canonical_url
    seo_data[:canonical_url].presence || request.original_url.split('?').first
  end

  # Get OG image URL
  def seo_image
    image = seo_data[:image]

    if image.present?
      # Handle ActiveStorage attachments
      if image.respond_to?(:url)
        image.url
      elsif image.respond_to?(:attached?) && image.attached?
        rails_blob_url(image, only_path: false)
      else
        image
      end
    else
      # Fallback to website logo or default
      current_website&.logo_url.presence
    end
  end

  # Generate favicon link tags
  def favicon_tags
    tags = []

    # Default PWB favicon from public directory
    # Tenants can override by uploading their own favicon via website settings
    tags << tag.link(rel: 'icon', href: '/favicon.ico', sizes: 'any')
    tags << tag.link(rel: 'icon', href: '/icon.svg', type: 'image/svg+xml')
    tags << tag.link(rel: 'apple-touch-icon', href: '/icon.png')

    safe_join(tags, "\n")
  end

  # Generate all meta tags
  def seo_meta_tags
    tags = []

    # Favicon tags
    tags << favicon_tags

    # Basic meta tags
    tags << tag.meta(name: 'description', content: seo_description) if seo_description.present?

    # Canonical URL
    tags << tag.link(rel: 'canonical', href: seo_canonical_url)

    # Open Graph tags
    tags << tag.meta(property: 'og:type', content: seo_data[:og_type] || 'website')
    tags << tag.meta(property: 'og:title', content: seo_title)
    tags << tag.meta(property: 'og:description', content: seo_description) if seo_description.present?
    tags << tag.meta(property: 'og:url', content: seo_canonical_url)
    tags << tag.meta(property: 'og:site_name', content: current_website&.company_display_name.presence || 'PropertyWebBuilder')
    tags << tag.meta(property: 'og:image', content: seo_image) if seo_image.present?
    tags << tag.meta(property: 'og:locale', content: I18n.locale.to_s.tr('-', '_'))

    # Twitter Card tags
    tags << tag.meta(name: 'twitter:card', content: seo_image.present? ? 'summary_large_image' : 'summary')
    tags << tag.meta(name: 'twitter:title', content: seo_title)
    tags << tag.meta(name: 'twitter:description', content: seo_description) if seo_description.present?
    tags << tag.meta(name: 'twitter:image', content: seo_image) if seo_image.present?

    # Hreflang tags for multi-language support
    if seo_data[:alternate_urls].present?
      seo_data[:alternate_urls].each do |locale, url|
        tags << tag.link(rel: 'alternate', hreflang: locale, href: url)
      end
    end

    # Robots directive if specified
    if seo_data[:noindex] || seo_data[:nofollow]
      directives = []
      directives << 'noindex' if seo_data[:noindex]
      directives << 'nofollow' if seo_data[:nofollow]
      tags << tag.meta(name: 'robots', content: directives.join(', '))
    end

    safe_join(tags, "\n")
  end

  # Generate JSON-LD structured data for a property
  def property_json_ld(prop)
    return nil unless prop.present?

    data = {
      '@context' => 'https://schema.org',
      '@type' => 'RealEstateListing',
      'name' => prop.title,
      'description' => truncate(strip_tags(prop.description), length: 500),
      'url' => seo_canonical_url
    }

    # Price information - use money-rails attributes
    if prop.for_sale? && prop.price_sale_current_cents.present? && prop.price_sale_current_cents > 0
      data['offers'] = {
        '@type' => 'Offer',
        'price' => prop.price_sale_current_cents / 100.0,
        'priceCurrency' => prop.price_sale_current_currency || prop.currency || 'EUR',
        'availability' => 'https://schema.org/InStock'
      }
    elsif prop.for_rent? && prop.price_rental_monthly_current_cents.present? && prop.price_rental_monthly_current_cents > 0
      data['offers'] = {
        '@type' => 'Offer',
        'price' => prop.price_rental_monthly_current_cents / 100.0,
        'priceCurrency' => prop.price_rental_monthly_current_currency || prop.currency || 'EUR',
        'availability' => 'https://schema.org/InStock'
      }
    end

    # Location
    if prop.respond_to?(:address) && prop.address.present?
      address = prop.address
      data['address'] = {
        '@type' => 'PostalAddress',
        'streetAddress' => address.street.presence,
        'addressLocality' => address.city.presence || address.locality.presence,
        'addressRegion' => address.region.presence || address.province.presence,
        'postalCode' => address.postal_code.presence,
        'addressCountry' => address.country.presence
      }.compact
    end

    # Property features
    data['numberOfRooms'] = prop.count_bedrooms if prop.respond_to?(:count_bedrooms) && prop.count_bedrooms.present?
    data['numberOfBathroomsTotal'] = prop.count_bathrooms if prop.respond_to?(:count_bathrooms) && prop.count_bathrooms.present?

    # Floor size
    if prop.respond_to?(:plot_area) && prop.plot_area.present?
      data['floorSize'] = {
        '@type' => 'QuantitativeValue',
        'value' => prop.plot_area,
        'unitCode' => 'MTK' # Square meters
      }
    end

    # Images
    if prop.respond_to?(:photos) && prop.photos.any?
      data['image'] = prop.photos.first(5).map { |photo| photo_url(photo) }.compact
    elsif prop.respond_to?(:prop_photos) && prop.prop_photos.any?
      data['image'] = prop.prop_photos.first(5).map { |pp| pp.image_url }.compact
    end

    # Date posted
    data['datePosted'] = prop.created_at.iso8601 if prop.respond_to?(:created_at)

    tag.script(data.to_json.html_safe, type: 'application/ld+json')
  end

  # Generate JSON-LD for organization/website
  def organization_json_ld
    return nil unless current_website.present?

    data = {
      '@context' => 'https://schema.org',
      '@type' => 'RealEstateAgent',
      'name' => current_website.company_display_name.presence || current_website.subdomain,
      'url' => root_url
    }

    data['logo'] = current_website.logo_url if current_website.respond_to?(:logo_url) && current_website.logo_url.present?
    data['description'] = current_website.default_meta_description if current_website.default_meta_description.present?

    # Contact info from agency if available
    if current_website.respond_to?(:agency) && current_website.agency.present?
      agency = current_website.agency
      data['telephone'] = agency.phone if agency.respond_to?(:phone) && agency.phone.present?
      data['email'] = agency.email if agency.respond_to?(:email) && agency.email.present?
    end

    tag.script(data.to_json.html_safe, type: 'application/ld+json')
  end

  # Generate breadcrumb JSON-LD
  def breadcrumb_json_ld(breadcrumbs)
    return nil unless breadcrumbs.present? && breadcrumbs.any?

    items = breadcrumbs.each_with_index.map do |crumb, index|
      {
        '@type' => 'ListItem',
        'position' => index + 1,
        'name' => crumb[:name],
        'item' => crumb[:url]
      }
    end

    data = {
      '@context' => 'https://schema.org',
      '@type' => 'BreadcrumbList',
      'itemListElement' => items
    }

    tag.script(data.to_json.html_safe, type: 'application/ld+json')
  end

  private

  def current_website
    return @current_website if defined?(@current_website)
    @current_website = Pwb::Current.website rescue nil
  end

  def photo_url(photo)
    if photo.respond_to?(:image_url)
      photo.image_url
    elsif photo.respond_to?(:url)
      photo.url
    end
  end
end
