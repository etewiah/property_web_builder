# frozen_string_literal: true

module SiteAdmin
  module Props
    # SaleListingsController
    # Manages sale listings for a specific realty asset (property)
    class SaleListingsController < SiteAdminController
      before_action :set_realty_asset
      before_action :set_sale_listing, only: [:edit, :update, :destroy, :activate, :archive, :unarchive]

      def new
        @sale_listing = @realty_asset.sale_listings.build
      end

      def create
        @sale_listing = @realty_asset.sale_listings.build(sale_listing_params)

        if @sale_listing.save
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Sale listing created successfully.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        # @sale_listing set by before_action
      end

      def update
        if @sale_listing.update(sale_listing_params)
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Sale listing updated successfully.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @sale_listing.active?
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      alert: 'Cannot delete the active listing. Activate another listing first.'
        elsif @sale_listing.destroy
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Sale listing deleted successfully.'
        else
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      alert: 'Failed to delete sale listing.'
        end
      end

      def activate
        @sale_listing.activate!
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    notice: 'Sale listing activated successfully.'
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    alert: "Failed to activate listing: #{e.message}"
      end

      def archive
        if @sale_listing.active?
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      alert: 'Cannot archive the active listing. Activate another listing first.'
        else
          @sale_listing.archive!
          redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                      notice: 'Sale listing archived successfully.'
        end
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    alert: "Failed to archive listing: #{e.message}"
      end

      def unarchive
        @sale_listing.unarchive!
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    notice: 'Sale listing unarchived successfully.'
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_sale_rental_site_admin_prop_path(@realty_asset),
                    alert: "Failed to unarchive listing: #{e.message}"
      end

      private

      def set_realty_asset
        @realty_asset = Pwb::RealtyAsset.where(website_id: current_website&.id).find(params[:prop_id])
      end

      def set_sale_listing
        @sale_listing = @realty_asset.sale_listings.find(params[:id])
      end

      def sale_listing_params
        # Include title/description for each supported locale
        locale_fields = I18n.available_locales.flat_map do |locale|
          ["title_#{locale}".to_sym, "description_#{locale}".to_sym]
        end

        params.require(:sale_listing).permit(
          :visible, :highlighted, :archived, :reserved, :furnished, :active,
          :price_sale_current_cents, :price_sale_current_currency,
          :commission_cents, :commission_currency,
          *locale_fields
        )
      end
    end
  end
end
