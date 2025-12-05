# frozen_string_literal: true

module SiteAdmin
  module Props
    # RentalListingsController
    # Manages rental listings for a specific realty asset (property)
    class RentalListingsController < SiteAdminController
      before_action :set_realty_asset
      before_action :set_rental_listing, only: [:edit, :update, :destroy, :activate, :archive, :unarchive]

      def new
        @rental_listing = @realty_asset.rental_listings.build
      end

      def create
        @rental_listing = @realty_asset.rental_listings.build(rental_listing_params)

        if @rental_listing.save
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Rental listing created successfully.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        # @rental_listing set by before_action
      end

      def update
        if @rental_listing.update(rental_listing_params)
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Rental listing updated successfully.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @rental_listing.active?
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      alert: 'Cannot delete the active listing. Activate another listing first.'
        elsif @rental_listing.destroy
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Rental listing deleted successfully.'
        else
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      alert: 'Failed to delete rental listing.'
        end
      end

      def activate
        @rental_listing.activate!
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    notice: 'Rental listing activated successfully.'
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    alert: "Failed to activate listing: #{e.message}"
      end

      def archive
        if @rental_listing.active?
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      alert: 'Cannot archive the active listing. Activate another listing first.'
        else
          @rental_listing.archive!
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Rental listing archived successfully.'
        end
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    alert: "Failed to archive listing: #{e.message}"
      end

      def unarchive
        @rental_listing.unarchive!
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    notice: 'Rental listing unarchived successfully.'
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    alert: "Failed to unarchive listing: #{e.message}"
      end

      private

      def set_realty_asset
        @realty_asset = Pwb::RealtyAsset.where(website_id: current_website&.id).find(params[:prop_id])
      end

      def set_rental_listing
        @rental_listing = @realty_asset.rental_listings.find(params[:id])
      end

      def rental_listing_params
        # Include title/description for each supported locale
        locale_fields = I18n.available_locales.flat_map do |locale|
          ["title_#{locale}".to_sym, "description_#{locale}".to_sym]
        end

        params.require(:rental_listing).permit(
          :visible, :highlighted, :archived, :reserved, :furnished, :active,
          :for_rent_short_term, :for_rent_long_term,
          :price_rental_monthly_current_cents, :price_rental_monthly_current_currency,
          :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents,
          *locale_fields
        )
      end
    end
  end
end
