# frozen_string_literal: true

# Website::SocialLinkable
#
# Provides social media link accessors for websites.
# Retrieves social media URLs from the links association.
#
# Performance: All social media links are loaded in a single query and memoized
# to avoid N+1 queries when accessing multiple social media platforms.
#
module Website
  module SocialLinkable
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
  end
end
