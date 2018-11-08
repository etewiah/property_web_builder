module Pwb
  class Api::V1::SubscribersController < ApplicationApiController
    protect_from_forgery with: :null_session
    respond_to :json

    def update
      contact = Pwb::Contact.find_by_id(params[:contact][:id]) 
      contact.first_name =  params[:contact][:first_name]
      contact.primary_email =  params[:contact][:primary_email]
      contact.primary_phone_number =  params[:contact][:primary_phone_number]
      contact.save!
      render json: {
        subscriber: contact.subscriber,
        # props: subscriber.props,
        contact: contact
      }
    end

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
      contact = Pwb::Contact.find_or_create_by(first_name: params[:subscriber][:name])
      contact.primary_email =  params[:subscriber][:primary_email]
      contact.primary_phone_number =  params[:subscriber][:primary_phone_number]
      contact.save!

      unless contact.subscriber.present?
        subscriber_token = (0...12).map { (65 + rand(26)).chr }.join
        subscriber = Pwb::Subscriber.create({
          subscriber_token: subscriber_token
          # subscriber_url: ""
        })
        contact.subscriber = subscriber
      else
        subscriber = contact.subscriber
      end
      render json: {
        subscriber: subscriber,
        contact: contact
      }
    end

    private

    def create_subscriber_params
      params.require(:subscriber).permit(
        :name, :last_name
      )
    end
    # def create
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
