# frozen_string_literal: true

module SiteAdmin
  # ContactsController
  # Manages contacts for the current website
  class ContactsController < SiteAdminController
    def index
      @contacts = Pwb::Contact.order(created_at: :desc).limit(100)

      # Search functionality
      if params[:search].present?
        @contacts = @contacts.where('primary_email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?',
                                   "%#{params[:search]}%",
                                   "%#{params[:search]}%",
                                   "%#{params[:search]}%")
      end
    end

    def show
      @contact = Pwb::Contact.find(params[:id])
    end
  end
end
