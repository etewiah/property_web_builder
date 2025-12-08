# frozen_string_literal: true

module Pwb
  # SaleListing represents a sale transaction for a property.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::SaleListing for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class SaleListing < ApplicationRecord
    include NtfyListingNotifications
    extend Mobility

    self.table_name = 'pwb_sale_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_sale_current_cents, with_model_currency: :price_sale_current_currency
    monetize :commission_cents, with_model_currency: :commission_currency

    # Mobility translations for listing marketing text
    # locale_accessors configured globally provides title_en, title_es, etc.
    translates :title, :description

    # Validations
    validate :only_one_active_per_realty_asset, if: :active?
    validate :cannot_delete_active_listing, on: :destroy

    # Scopes
    scope :visible, -> { where(visible: true) }
    scope :highlighted, -> { where(highlighted: true) }
    scope :archived, -> { where(archived: true) }
    scope :not_archived, -> { where(archived: false) }
    scope :active_listing, -> { where(active: true) }
    # Legacy scope - now refers to the active listing that is visible
    scope :active, -> { where(active: true, visible: true, archived: false) }

    # Refresh the materialized view after changes
    after_commit :refresh_properties_view

    # Callbacks for managing active state
    before_save :deactivate_other_listings, if: :will_activate?
    after_save :ensure_active_listing_visible, if: :saved_change_to_active?

    # Delegate common attributes to realty_asset for convenience
    delegate :reference, :website, :website_id,
             :count_bedrooms, :count_bathrooms, :street_address, :city,
             :prop_photos, :features, to: :realty_asset, allow_nil: true

    # Instance methods

    # Activate this listing, deactivating any other active listing for same asset
    def activate!
      transaction do
        realty_asset.sale_listings.where.not(id: id).update_all(active: false)
        update!(active: true, archived: false)
      end
    end

    # Deactivate this listing
    def deactivate!
      update!(active: false)
    end

    # Archive this listing (cannot archive if active, must deactivate first)
    def archive!
      raise ActiveRecord::RecordInvalid.new(self), "Cannot archive the active listing" if active?
      update!(archived: true, visible: false)
    end

    # Unarchive this listing
    def unarchive!
      update!(archived: false)
    end

    # Check if this listing can be deleted
    def can_destroy?
      !active?
    end

    private

    def only_one_active_per_realty_asset
      if realty_asset && realty_asset.sale_listings.active_listing.where.not(id: id).exists?
        errors.add(:active, "listing already exists for this property. Deactivate the current active listing first.")
      end
    end

    def cannot_delete_active_listing
      if active?
        errors.add(:base, "Cannot delete the active listing. Deactivate it first or activate another listing.")
        throw :abort
      end
    end

    def will_activate?
      active? && active_changed?
    end

    def deactivate_other_listings
      realty_asset&.sale_listings&.where&.not(id: id)&.update_all(active: false)
    end

    def ensure_active_listing_visible
      # If marking as active, ensure it's not archived
      if active? && archived?
        update_column(:archived, false)
      end
    end

    def refresh_properties_view
      Pwb::ListedProperty.refresh
    rescue StandardError => e
      Rails.logger.warn "Failed to refresh properties view: #{e.message}"
    end
  end
end
