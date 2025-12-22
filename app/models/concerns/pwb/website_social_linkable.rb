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
  end
end
