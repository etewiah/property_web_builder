module Pwb
  class Api::V1::ContactsController < ApplicationApiController

    respond_to :json

    def create
      Pwb::Contact.create create_contact_params
    end

    def update
      contact = Pwb::Contact.find_by_id params[:id]
      contact.update update_contact_params
      return render json: contact.as_json
    end

    def show
      contact = Pwb::Contact.find_by_id params[:id]
      return render json: contact.as_json
    end

    def index
      contacts = Pwb::Contact.all
      return render json: contacts.as_json
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
