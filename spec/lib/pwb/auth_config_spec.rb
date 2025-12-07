# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::AuthConfig do
  before do
    # Reset the provider before each test
    described_class.instance_variable_set(:@provider, nil)
  end

  after do
    # Clean up after tests
    described_class.instance_variable_set(:@provider, nil)
    ENV['AUTH_PROVIDER'] = 'firebase'
  end

  describe '.provider' do
    it 'defaults to firebase from environment' do
      ENV['AUTH_PROVIDER'] = 'firebase'
      described_class.instance_variable_set(:@provider, nil)
      expect(described_class.provider).to eq(:firebase)
    end

    it 'can be set to devise' do
      described_class.provider = :devise
      expect(described_class.provider).to eq(:devise)
    end

    it 'raises error for invalid provider' do
      expect { described_class.provider = :invalid }.to raise_error(ArgumentError)
    end
  end

  describe '.firebase?' do
    it 'returns true when provider is firebase' do
      ENV['AUTH_PROVIDER'] = 'firebase'
      described_class.instance_variable_set(:@provider, nil)
      expect(described_class.firebase?).to be true
    end

    it 'returns false when provider is devise' do
      described_class.provider = :devise
      expect(described_class.firebase?).to be false
    end
  end

  describe '.devise?' do
    it 'returns true when provider is devise' do
      described_class.provider = :devise
      expect(described_class.devise?).to be true
    end

    it 'returns false when provider is firebase' do
      ENV['AUTH_PROVIDER'] = 'firebase'
      described_class.instance_variable_set(:@provider, nil)
      expect(described_class.devise?).to be false
    end
  end

  describe '.login_path' do
    context 'when firebase provider' do
      before do
        ENV['AUTH_PROVIDER'] = 'firebase'
        described_class.instance_variable_set(:@provider, nil)
      end

      it 'returns firebase login path' do
        expect(described_class.login_path).to eq('/firebase_login')
      end
    end

    context 'when devise provider' do
      before { described_class.provider = :devise }

      it 'returns devise login path without locale' do
        expect(described_class.login_path).to eq('/users/sign_in')
      end

      it 'returns devise login path with locale' do
        expect(described_class.login_path(locale: :es)).to eq('/es/users/sign_in')
      end
    end
  end

  describe '.signup_path' do
    context 'when firebase provider' do
      before do
        ENV['AUTH_PROVIDER'] = 'firebase'
        described_class.instance_variable_set(:@provider, nil)
      end

      it 'returns firebase signup path' do
        expect(described_class.signup_path).to eq('/firebase_sign_up')
      end
    end

    context 'when devise provider' do
      before { described_class.provider = :devise }

      it 'returns devise signup path without locale' do
        expect(described_class.signup_path).to eq('/users/sign_up')
      end

      it 'returns devise signup path with locale' do
        expect(described_class.signup_path(locale: :fr)).to eq('/fr/users/sign_up')
      end
    end
  end

  describe '.forgot_password_path' do
    context 'when firebase provider' do
      before do
        ENV['AUTH_PROVIDER'] = 'firebase'
        described_class.instance_variable_set(:@provider, nil)
      end

      it 'returns firebase forgot password path' do
        expect(described_class.forgot_password_path).to eq('/firebase_forgot_password')
      end
    end

    context 'when devise provider' do
      before { described_class.provider = :devise }

      it 'returns devise password path without locale' do
        expect(described_class.forgot_password_path).to eq('/users/password/new')
      end
    end
  end

  describe '.logout_path' do
    it 'always returns unified logout path' do
      expect(described_class.logout_path).to eq('/auth/logout')
    end
  end

  describe '.config_summary' do
    it 'returns a hash with configuration details' do
      summary = described_class.config_summary
      expect(summary).to be_a(Hash)
      expect(summary).to have_key(:provider)
      expect(summary).to have_key(:login_path)
      expect(summary).to have_key(:logout_path)
    end
  end
end
