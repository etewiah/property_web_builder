# frozen_string_literal: true

module SiteAdmin
  # ContactsController
  # Manages contacts for the current website
  class ContactsController < SiteAdminController
    def index
      # Scope to current website for multi-tenant isolation
      @contacts = Pwb::Contact.where(website_id: current_website&.id).order(created_at: :desc).limit(100)

      # Search functionality
      if params[:search].present?
        @contacts = @contacts.where('primary_email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?',
                                   "%#{params[:search]}%",
                                   "%#{params[:search]}%",
                                   "%#{params[:search]}%")
      end
    end

    def show
      # Scope to current website for security
      @contact = Pwb::Contact.where(website_id: current_website&.id).find(params[:id])
    end
  end
end
