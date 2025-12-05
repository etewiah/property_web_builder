module Pwb
  class Api::V1::ContactsController < ApplicationApiController
    respond_to :json

    def create
      # Associate contact with current website for multi-tenant isolation
      current_website.contacts.create create_contact_params
    end

    def update
      # Scope to current website for security
      contact = current_website.contacts.find_by_id params[:id]
      return render json: { error: 'Contact not found' }, status: :not_found unless contact

      contact.update update_contact_params
      render json: contact.as_json
    end

    def show
      # Scope to current website for security
      contact = current_website.contacts.find_by_id params[:id]
      return render json: { error: 'Contact not found' }, status: :not_found unless contact

      render json: contact.as_json
    end

    def index
      # Scope to current website for multi-tenant isolation
      contacts = current_website.contacts
      render json: contacts.as_json
    end

    private

    def create_contact_params
      params.require(:details).permit(
        :first_name, :last_name
      )
    end

    def update_contact_params
      params.require(:details).permit(
        :first_name, :last_name
      )
    end
  end
end
