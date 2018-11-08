module Pwb
  class Api::V1::SubscribersController < ApplicationApiController
    protect_from_forgery with: :null_session
    respond_to :json

    def index
      subscribers = Pwb::Subscriber.all
      render json: {
        subscribers: subscribers
      }
    end

    def show
      subscriber = Pwb::Subscriber.find_by_id(params[:id]) || Pwb::Subscriber.first
      render json: {
        subscriber: subscriber,
        props: subscriber.props,
        contact: subscriber.contact
      }
    end

    def create
      new_contact = Pwb::Contact.find_or_create_by(first_name: params["subscriber"]["name"])
      unless new_contact.subscriber.present?
        new_subscriber = Pwb::Subscriber.create({
          subscriber_token: "ewiohjsdf"
          # subscriber_url: ""
        })
        new_contact.subscriber = new_subscriber
      end
      render json: {
        subscriber: new_subscriber,
        contact: new_contact
      }
    end

    private

    def create_subscriber_params
      params.require(:subscriber).permit(
        :name, :last_name
      )
    end
    # def create
    #   byebug
    #   themes = Theme.all
    #   # Theme is active_hash so have to manually construct json
    #   @themes_array = []
    #   themes.each do |theme|
    #     @themes_array.push theme.as_json["attributes"]
    #   end
    #   render json: @themes_array
    # end
  end
end
