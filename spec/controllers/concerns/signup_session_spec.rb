# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignupSession do
  let(:session) { {} }
  let(:manager) { SignupSession::SignupSessionManager.new(session) }
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, website: website) }

  describe SignupSession::SignupSessionManager do
    describe 'user accessors' do
      describe '#user_id and #user_id=' do
        it 'stores and retrieves user_id from session' do
          manager.user_id = 123
          expect(manager.user_id).to eq(123)
          expect(session[:signup_user_id]).to eq(123)
        end
      end

      describe '#user' do
        it 'returns nil when no user_id is set' do
          expect(manager.user).to be_nil
        end

        it 'finds user by id' do
          manager.user_id = user.id
          expect(manager.user).to eq(user)
        end

        it 'memoizes the user lookup' do
          manager.user_id = user.id
          expect(Pwb::User).to receive(:find_by).once.and_return(user)
          2.times { manager.user }
        end
      end

      describe '#user=' do
        it 'sets user and user_id' do
          manager.user = user
          expect(manager.user_id).to eq(user.id)
          expect(manager.user).to eq(user)
        end

        it 'handles nil user' do
          manager.user = nil
          expect(manager.user_id).to be_nil
        end
      end
    end

    describe 'subdomain accessors' do
      describe '#subdomain and #subdomain=' do
        it 'stores and retrieves subdomain from session' do
          manager.subdomain = 'my-site'
          expect(manager.subdomain).to eq('my-site')
          expect(session[:signup_subdomain]).to eq('my-site')
        end
      end
    end

    describe 'website accessors' do
      describe '#website_id and #website_id=' do
        it 'stores and retrieves website_id from session' do
          manager.website_id = 456
          expect(manager.website_id).to eq(456)
          expect(session[:signup_website_id]).to eq(456)
        end
      end

      describe '#website' do
        it 'returns nil when no website_id is set' do
          expect(manager.website).to be_nil
        end

        it 'finds website by id' do
          manager.website_id = website.id
          expect(manager.website).to eq(website)
        end
      end

      describe '#website=' do
        it 'sets website and website_id' do
          manager.website = website
          expect(manager.website_id).to eq(website.id)
          expect(manager.website).to eq(website)
        end
      end
    end

    describe 'state checks' do
      describe '#has_user?' do
        it 'returns false when no user' do
          expect(manager.has_user?).to be false
        end

        it 'returns true when user exists' do
          manager.user = user
          expect(manager.has_user?).to be true
        end
      end

      describe '#has_website?' do
        it 'returns false when no website' do
          expect(manager.has_website?).to be false
        end

        it 'returns true when website exists' do
          manager.website = website
          expect(manager.has_website?).to be true
        end
      end

      describe '#complete?' do
        it 'returns false when website is not live' do
          website.update!(provisioning_state: 'pending')
          manager.website = website
          manager.user = user
          expect(manager.complete?).to be false
        end

        it 'returns false when user is not active' do
          website.update!(provisioning_state: 'live')
          manager.website = website
          allow(user).to receive(:active?).and_return(false)
          manager.user = user
          expect(manager.complete?).to be false
        end

        it 'returns true when website is live and user is active' do
          website.update!(provisioning_state: 'live')
          manager.website = website
          allow(user).to receive(:active?).and_return(true)
          manager.user = user
          expect(manager.complete?).to be true
        end
      end
    end

    describe '#current_step' do
      it 'returns 1 when no user' do
        expect(manager.current_step).to eq(1)
      end

      it 'returns 2 when user exists but no website' do
        manager.user = user
        expect(manager.current_step).to eq(2)
      end

      it 'returns 3 when website exists but not complete' do
        website.update!(provisioning_state: 'pending')
        manager.user = user
        manager.website = website
        expect(manager.current_step).to eq(3)
      end

      it 'returns 4 when complete' do
        website.update!(provisioning_state: 'live')
        allow(user).to receive(:active?).and_return(true)
        manager.user = user
        manager.website = website
        expect(manager.current_step).to eq(4)
      end
    end

    describe '#clear' do
      before do
        manager.user = user
        manager.subdomain = 'test-site'
        manager.website = website
      end

      it 'clears all session keys' do
        manager.clear
        expect(session[:signup_user_id]).to be_nil
        expect(session[:signup_subdomain]).to be_nil
        expect(session[:signup_website_id]).to be_nil
      end

      it 'clears memoized values' do
        manager.clear
        expect(manager.user).to be_nil
        expect(manager.website).to be_nil
      end
    end

    describe '#store_start_result' do
      let(:subdomain) { double('Subdomain', name: 'new-site') }
      let(:result) { { user: user, subdomain: subdomain } }

      it 'stores user and subdomain from result' do
        manager.store_start_result(result)
        expect(manager.user).to eq(user)
        expect(manager.subdomain).to eq('new-site')
      end

      it 'handles nil subdomain' do
        result[:subdomain] = nil
        manager.store_start_result(result)
        expect(manager.subdomain).to be_nil
      end
    end

    describe '#store_configure_result' do
      let(:result) { { website: website } }

      it 'stores website from result' do
        manager.store_configure_result(result)
        expect(manager.website).to eq(website)
      end
    end
  end

  describe 'controller integration' do
    let(:controller_class) do
      Class.new(ActionController::Base) do
        include SignupSession
      end
    end

    let(:controller) { controller_class.new }

    before do
      allow(controller).to receive(:session).and_return(session)
    end

    describe '#signup_session' do
      it 'returns a SignupSessionManager instance' do
        expect(controller.signup_session).to be_a(SignupSession::SignupSessionManager)
      end

      it 'memoizes the manager' do
        expect(controller.signup_session).to be(controller.signup_session)
      end
    end

    describe '#clear_signup_session' do
      it 'delegates to manager.clear' do
        controller.signup_session.user_id = 123
        controller.clear_signup_session
        expect(session[:signup_user_id]).to be_nil
      end
    end
  end
end
