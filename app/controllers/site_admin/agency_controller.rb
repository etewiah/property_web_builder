# frozen_string_literal: true

module SiteAdmin
  # AgencyController
  # Manages the agency/company profile for the current website
  class AgencyController < SiteAdminController
    before_action :set_agency

    def edit
      # @agency set by before_action
    end

    def update
      if @agency.update(agency_params)
        redirect_to edit_site_admin_agency_path, notice: 'Agency profile updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_agency
      @agency = current_website.agency || current_website.create_agency!
    end

    def agency_params
      params.require(:pwb_agency).permit(
        :display_name,
        :company_name,
        :email_primary,
        :email_for_general_contact_form,
        :email_for_property_contact_form,
        :phone_number_primary,
        :phone_number_mobile,
        :phone_number_other,
        :url,
        :skype
      )
    end
  end
end
