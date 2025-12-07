# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthHelper, type: :helper do
  before do
    # Reset the provider before each test
    Pwb::AuthConfig.instance_variable_set(:@provider, nil)
  end

  after do
    # Clean up after tests
    Pwb::AuthConfig.instance_variable_set(:@provider, nil)
    ENV['AUTH_PROVIDER'] = 'firebase'
  end

  describe '#auth_login_path' do
    context 'when firebase provider' do
      before do
        ENV['AUTH_PROVIDER'] = 'firebase'
        Pwb::AuthConfig.instance_variable_set(:@provider, nil)
      end

      it 'returns firebase login path' do
        expect(helper.auth_login_path).to eq('/firebase_login')
      end

      it 'includes return_to parameter when provided' do
        path = helper.auth_login_path(return_to: '/admin')
        expect(path).to include('return_to=')
        expect(path).to include('%2Fadmin')
      end
    end

    context 'when devise provider' do
      before do
        Pwb::AuthConfig.provider = :devise
        allow(I18n).to receive(:locale).and_return(:en)
      end

      it 'returns devise login path with locale' do
        expect(helper.auth_login_path).to eq('/en/users/sign_in')
      end
    end
  end

  describe '#auth_signup_path' do
    context 'when firebase provider' do
      before do
        ENV['AUTH_PROVIDER'] = 'firebase'
        Pwb::AuthConfig.instance_variable_set(:@provider, nil)
      end

      it 'returns firebase signup path' do
        expect(helper.auth_signup_path).to eq('/firebase_sign_up')
      end
    end
  end

  describe '#auth_logout_path' do
    it 'returns unified logout path' do
      expect(helper.auth_logout_path).to eq('/auth/logout')
    end
  end

  describe '#using_firebase_auth?' do
    context 'when firebase provider' do
      before do
        ENV['AUTH_PROVIDER'] = 'firebase'
        Pwb::AuthConfig.instance_variable_set(:@provider, nil)
      end

      it 'returns true' do
        expect(helper.using_firebase_auth?).to be true
      end
    end

    context 'when devise provider' do
      before { Pwb::AuthConfig.provider = :devise }

      it 'returns false' do
        expect(helper.using_firebase_auth?).to be false
      end
    end
  end

  describe '#using_devise_auth?' do
    context 'when devise provider' do
      before { Pwb::AuthConfig.provider = :devise }

      it 'returns true' do
        expect(helper.using_devise_auth?).to be true
      end
    end

    context 'when firebase provider' do
      before do
        ENV['AUTH_PROVIDER'] = 'firebase'
        Pwb::AuthConfig.instance_variable_set(:@provider, nil)
      end

      it 'returns false' do
        expect(helper.using_devise_auth?).to be false
      end
    end
  end

  describe '#current_auth_provider' do
    it 'returns :firebase when firebase provider' do
      ENV['AUTH_PROVIDER'] = 'firebase'
      Pwb::AuthConfig.instance_variable_set(:@provider, nil)
      expect(helper.current_auth_provider).to eq(:firebase)
    end

    it 'returns :devise when devise provider' do
      Pwb::AuthConfig.provider = :devise
      expect(helper.current_auth_provider).to eq(:devise)
    end
  end
end
