require 'rails_helper'

module Pwb
  RSpec.describe 'PropertyWebBuilder routing ', type: :routing do
    routes { Pwb::Engine.routes }
    describe 'root url' do
      it 'routes to welcome_controller#index' do
        expect(get: '/').to route_to(
          controller: 'pwb/welcome',
          action: 'index'
        )
      end


      context 'with locale parameter' do
        it 'routes to welcome_controller#index' do
          expect({
            get: '/en'
          }).to route_to(
            controller: 'pwb/welcome',
            action: 'index',
            locale: 'en'
          )
        end
      end
    end
    describe 'welcome routing' do
      it 'routes to welcome_controller#index' do
        expect(get: '/welcome').to route_to('pwb/welcome#index')
      end
    end

    describe 'devise routing' do
      it 'routes to devise_controller#index' do
        expect(get: '/en/users/sign_in').to route_to(
          controller: 'devise/sessions',
          action: 'new',
          locale: 'en'
        )
      end
    end

  end
end
