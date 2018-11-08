module Pwb
  class Api::V1::SubscriberPropsController < ApplicationApiController
    protect_from_forgery with: :null_session
    respond_to :json

    def update
      prop = Pwb::Prop.find params[:property][:id]
      subscriber = Pwb::Subscriber.find params[:subscriber][:id]
      if params[:update_action] == "add"
        unless subscriber.props.include? prop
          # TODO - enforce uniqueness in relation
          subscriber.props << prop          
        end
      else
        subscriber.props.delete prop
      end
      render json: {
        subscriber: subscriber,
        props: subscriber.props,
        contact: subscriber.contact
      }
    end

    private

  end
end
