# frozen_string_literal: true

module ApiManage
  module V1
    # SppListingsController — Manage SPP (Single Property Page) listings
    #
    # Endpoints:
    #   POST /api_manage/v1/:locale/properties/:id/spp_publish   — Publish an SPP listing
    #   POST /api_manage/v1/:locale/properties/:id/spp_unpublish — Unpublish an SPP listing
    #   GET  /api_manage/v1/:locale/properties/:id/spp_leads     — Retrieve property enquiries
    #
    class SppListingsController < BaseController
      before_action :require_user!
      before_action :set_property

      # POST /api_manage/v1/:locale/properties/:id/spp_publish
      def publish
        listing_type = params[:listing_type] || 'sale'

        unless Pwb::SppListing::LISTING_TYPES.include?(listing_type)
          return render json: { success: false, error: "Invalid listing_type: must be 'sale' or 'rental'" },
                        status: :unprocessable_entity
        end

        template = current_website.client_theme_config&.dig('spp_url_template')
        unless template.present?
          return render json: { success: false, error: 'spp_url_template not configured in client_theme_config' },
                        status: :unprocessable_entity
        end

        listing = @property.spp_listings.find_or_initialize_by(listing_type: listing_type)
        listing.assign_attributes(
          active: true,
          visible: true,
          archived: false,
          published_at: Time.current,
          live_url: interpolate_live_url(template, listing_type)
        )
        listing.save!

        render json: {
          status: 'published',
          listingType: listing.listing_type,
          liveUrl: listing.live_url,
          publishedAt: listing.published_at.iso8601
        }
      end

      # POST /api_manage/v1/:locale/properties/:id/spp_unpublish
      def unpublish
        listing_type = params[:listing_type] || 'sale'

        unless Pwb::SppListing::LISTING_TYPES.include?(listing_type)
          return render json: { success: false, error: "Invalid listing_type: must be 'sale' or 'rental'" },
                        status: :unprocessable_entity
        end

        listing = @property.spp_listings.where(listing_type: listing_type, active: true).first
        unless listing
          return render json: { success: false, error: "No active SPP #{listing_type} listing found" },
                        status: :unprocessable_entity
        end

        listing.update!(visible: false)

        render json: {
          status: 'draft',
          listingType: listing.listing_type,
          liveUrl: nil
        }
      end

      # GET /api_manage/v1/:locale/properties/:id/spp_leads
      def leads
        messages = Pwb::Message.where(realty_asset_id: @property.id)
                               .order(created_at: :desc)

        render json: messages.map { |msg| lead_json(msg) }
      end

      private

      def set_property
        @property = Pwb::RealtyAsset.where(website_id: current_website.id)
                                     .find(params[:id])
      end

      def interpolate_live_url(template, listing_type)
        template
          .gsub('{slug}', @property.slug.to_s)
          .gsub('{uuid}', @property.id.to_s)
          .gsub('{listing_type}', listing_type)
          .gsub('{locale}', (params[:locale] || I18n.locale).to_s)
      end

      def lead_json(message)
        {
          id: message.id,
          name: message.sender_name,
          email: message.sender_email,
          phone: message.contact&.primary_phone_number,
          message: message.content,
          createdAt: message.created_at.iso8601,
          isNew: !message.read? || message.created_at > 48.hours.ago
        }
      end
    end
  end
end
