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
    alternate_urls = seo_data[:alternate_urls] || generate_alternate_urls
    if alternate_urls.present?
      alternate_urls.each do |locale, url|
        tags << tag.link(rel: 'alternate', hreflang: locale, href: url)
      end
      # Add x-default for language selection page
      tags << tag.link(rel: 'alternate', hreflang: 'x-default', href: alternate_urls[I18n.default_locale.to_s] || request.original_url)
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

    # Location - use direct property fields
    address_data = {
      '@type' => 'PostalAddress',
      'streetAddress' => prop.try(:street_address).presence,
      'addressLocality' => prop.try(:city).presence,
      'addressRegion' => prop.try(:region).presence || prop.try(:province).presence,
      'postalCode' => prop.try(:postal_code).presence,
      'addressCountry' => prop.try(:country).presence
    }.compact

    data['address'] = address_data if address_data.keys.size > 1 # Has more than just @type

    # Geo coordinates for mapping
    if prop.try(:latitude).present? && prop.try(:longitude).present?
      data['geo'] = {
        '@type' => 'GeoCoordinates',
        'latitude' => prop.latitude,
        'longitude' => prop.longitude
      }
    end

    # Property features
    data['numberOfRooms'] = prop.count_bedrooms if prop.respond_to?(:count_bedrooms) && prop.count_bedrooms.present?
    data['numberOfBathroomsTotal'] = prop.count_bathrooms if prop.respond_to?(:count_bathrooms) && prop.count_bathrooms.present?

    # Property type (e.g., apartment, house, villa)
    if prop.try(:prop_type_key).present?
      # Extract human-readable type from key like "propertyTypes.apartment"
      prop_type = prop.prop_type_key.split('.').last&.titleize
      data['propertyType'] = prop_type if prop_type.present?
    end

    # Year built
    if prop.try(:year_construction).present? && prop.year_construction > 0
      data['yearBuilt'] = prop.year_construction
    end

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

  # Set SEO for a CMS page
  def set_page_seo(page)
    return unless page.present?

    # Build canonical URL
    canonical_url = if page.slug == 'home'
                      "#{request.protocol}#{request.host_with_port}/"
                    else
                      "#{request.protocol}#{request.host_with_port}/p/#{page.slug}"
                    end

    set_seo(
      title: page.seo_title.presence || page.page_title,
      description: page.meta_description.presence,
      canonical_url: canonical_url,
      og_type: 'website'
    )

    # Store page for potential JSON-LD generation
    @seo_page = page
  end

  # Set SEO for search/listing pages
  def set_listing_page_seo(options = {})
    operation = options[:operation] # 'for_sale' or 'for_rent'
    location = options[:location]   # city, region, etc.
    page_num = options[:page] || 1

    # Build dynamic title based on search context
    title_parts = []
    title_parts << (operation == 'for_rent' ? I18n.t('forRent', default: 'For Rent') : I18n.t('forSale', default: 'For Sale'))
    title_parts << "in #{location}" if location.present?
    title_parts << "- Page #{page_num}" if page_num > 1

    # Build description
    description = I18n.t('seo.listing_description',
                         operation: title_parts.first,
                         location: location.presence || 'your area',
                         default: "Browse properties #{title_parts.first.downcase} #{location.present? ? "in #{location}" : ''}")

    # Canonical URL (without pagination for page 1)
    canonical_path = request.path.split('?').first
    canonical_url = "#{request.protocol}#{request.host_with_port}#{canonical_path}"

    set_seo(
      title: title_parts.join(' '),
      description: description,
      canonical_url: canonical_url,
      og_type: 'website'
    )
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

  # Generate alternate URLs for each available locale
  # Uses the current path with locale substitution
  def generate_alternate_urls
    return {} unless defined?(request) && request.present?
    return {} unless I18n.available_locales.size > 1

    base_url = "#{request.protocol}#{request.host_with_port}"
    current_path = request.path

    I18n.available_locales.each_with_object({}) do |locale, urls|
      # Replace locale in path or prepend it
      # Handles paths like /en/buy, /es/buy
      alternate_path = if current_path =~ %r{^/([a-z]{2})(/|$)}
                         current_path.sub(%r{^/[a-z]{2}}, "/#{locale}")
                       else
                         "/#{locale}#{current_path}"
                       end
      urls[locale.to_s] = "#{base_url}#{alternate_path}"
    end
  end
end
