# frozen_string_literal: true

# Website::SocialLinkable
#
# Provides social media link accessors for websites.
# Retrieves social media URLs from the links association.
#
module Pwb
  module WebsiteSocialLinkable
    extend ActiveSupport::Concern

    def social_media_facebook
      links.find_by(slug: "social_media_facebook")&.link_url
    end

    def social_media_twitter
      links.find_by(slug: "social_media_twitter")&.link_url
    end

    def social_media_linkedin
      links.find_by(slug: "social_media_linkedin")&.link_url
    end

    def social_media_youtube
      links.find_by(slug: "social_media_youtube")&.link_url
    end

    def social_media_pinterest
      links.find_by(slug: "social_media_pinterest")&.link_url
    end

    def social_media_instagram
      links.find_by(slug: "social_media_instagram")&.link_url
    end

    def social_media_whatsapp
      links.find_by(slug: "social_media_whatsapp")&.link_url
    end

    # Returns all social media platforms with their current values
    # Used by admin UI for editing
    SOCIAL_MEDIA_PLATFORMS = %w[facebook instagram linkedin youtube twitter whatsapp].freeze

    def social_media_links_for_admin
      SOCIAL_MEDIA_PLATFORMS.map do |platform|
        slug = "social_media_#{platform}"
        link = links.find_by(slug: slug)
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
      link.save
    end
  end
end
