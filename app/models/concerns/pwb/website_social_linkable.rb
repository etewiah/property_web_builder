# frozen_string_literal: true

# Website::SocialLinkable
#
# Provides social media link accessors for websites.
# Retrieves social media URLs from the links association.
#
# Performance: All social media links are loaded in a single query and memoized
# to avoid N+1 queries when accessing multiple social media platforms.
#
module Pwb
  module WebsiteSocialLinkable
    extend ActiveSupport::Concern

    # All supported social media platforms
    SOCIAL_MEDIA_PLATFORMS = %w[facebook instagram linkedin youtube twitter whatsapp pinterest].freeze

    # Load all social media links in one query and index by slug
    # This is memoized to avoid repeated queries within the same request
    def social_media_links_cache
      @social_media_links_cache ||= begin
        slugs = SOCIAL_MEDIA_PLATFORMS.map { |p| "social_media_#{p}" }
        links.where(slug: slugs).index_by(&:slug)
      end
    end

    # Clear the cache (call after updating social links)
    def clear_social_media_cache
      @social_media_links_cache = nil
    end

    def social_media_facebook
      social_media_links_cache["social_media_facebook"]&.link_url
    end

    def social_media_twitter
      social_media_links_cache["social_media_twitter"]&.link_url
    end

    def social_media_linkedin
      social_media_links_cache["social_media_linkedin"]&.link_url
    end

    def social_media_youtube
      social_media_links_cache["social_media_youtube"]&.link_url
    end

    def social_media_pinterest
      social_media_links_cache["social_media_pinterest"]&.link_url
    end

    def social_media_instagram
      social_media_links_cache["social_media_instagram"]&.link_url
    end

    def social_media_whatsapp
      social_media_links_cache["social_media_whatsapp"]&.link_url
    end

    # Returns all social media platforms with their current values
    # Used by admin UI for editing
    def social_media_links_for_admin
      SOCIAL_MEDIA_PLATFORMS.map do |platform|
        slug = "social_media_#{platform}"
        link = social_media_links_cache[slug]
        {
          platform: platform,
          slug: slug,
          url: link&.link_url,
          link_id: link&.id
        }
      end
    end

    def update_social_media_link(platform, url)
      slug = "social_media_#{platform}"
      link = links.find_or_initialize_by(slug: slug)
      link.assign_attributes(
        link_url: url.presence,
        placement: :social_media,
        visible: url.present?,
        icon_class: "fa fa-#{platform}"
      )
      result = link.save
      clear_social_media_cache if result
      result
    end
  end
end
