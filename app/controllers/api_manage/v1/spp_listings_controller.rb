# frozen_string_literal: true

module ApiManage
  module V1
    # SppListingsController — Manage SPP (Single Property Page) listings
    #
    # Endpoints:
    #   POST /api_manage/v1/:locale/properties/:id/spp_publish   — Publish an SPP listing
    #   POST /api_manage/v1/:locale/properties/:id/spp_unpublish — Unpublish an SPP listing
    #   GET  /api_manage/v1/:locale/properties/:id/spp_leads     — Retrieve property enquiries
    #   PUT  /api_manage/v1/:locale/spp_listings/:id             — Update SPP listing content
    #
    class SppListingsController < BaseController
      before_action :require_user!
      before_action :set_property, only: %i[publish unpublish leads]
      before_action :set_spp_listing, only: %i[update]
      before_action :setup_locale, only: %i[update]

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

      # PUT /api_manage/v1/:locale/spp_listings/:id
      def update
        if spp_listing_params.key?(:photo_ids_ordered)
          return unless valid_photo_ids?
        end

        attrs = spp_listing_params.to_h
        # Ensure photo IDs are stored as integers in JSONB
        if attrs.key?('photo_ids_ordered')
          attrs['photo_ids_ordered'] = attrs['photo_ids_ordered'].map(&:to_s).reject(&:blank?).map(&:to_i)
        end

        @spp_listing.assign_attributes(attrs)
        @spp_listing.save!

        render json: spp_listing_json(@spp_listing)
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

      def set_spp_listing
        @spp_listing = Pwb::SppListing
          .joins(:realty_asset)
          .where(pwb_realty_assets: { website_id: current_website.id })
          .find(params[:id])
      end

      def setup_locale
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale.to_sym
      end

      def spp_listing_params
        params.permit(
          :title, :description, :seo_title, :meta_description,
          :price_cents, :price_currency,
          :template,
          photo_ids_ordered: [],
          highlighted_features: [],
          spp_settings: {},
          extra_data: {}
        )
      end

      def valid_photo_ids?
        ids = spp_listing_params[:photo_ids_ordered]
        return true if ids.blank?

        # Filter out blanks that can come from empty array serialization
        int_ids = ids.map(&:to_s).reject(&:blank?).map(&:to_i)
        return true if int_ids.empty?

        valid_ids = @spp_listing.realty_asset.prop_photos.pluck(:id)
        invalid = int_ids - valid_ids
        return true if invalid.empty?

        render json: {
          success: false,
          error: 'Invalid photo IDs',
          message: "Photo IDs #{invalid.join(', ')} do not belong to this property"
        }, status: :unprocessable_entity
        false
      end

      def spp_listing_json(listing)
        {
          id: listing.id,
          listingType: listing.listing_type,
          title: listing.title,
          description: listing.description,
          seoTitle: listing.seo_title,
          metaDescription: listing.meta_description,
          priceCents: listing.price_cents,
          priceCurrency: listing.price_currency,
          photoIdsOrdered: listing.photo_ids_ordered,
          highlightedFeatures: listing.highlighted_features,
          template: listing.template,
          sppSettings: listing.spp_settings,
          extraData: listing.extra_data,
          active: listing.active,
          visible: listing.visible,
          liveUrl: listing.live_url,
          publishedAt: listing.published_at&.iso8601,
          updatedAt: listing.updated_at.iso8601
        }
      end
    end
  end
end
