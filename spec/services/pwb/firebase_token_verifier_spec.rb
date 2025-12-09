# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe FirebaseTokenVerifier do
    let(:project_id) { 'test-project-id' }
    let(:firebase_uid) { 'user-uid-12345' }
    let(:user_email) { 'test@example.com' }

    # Sample certificate (self-signed for testing)
    let(:test_private_key) { OpenSSL::PKey::RSA.new(2048) }
    let(:test_certificate) do
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.parse('/CN=test')
      cert.issuer = cert.subject
      cert.public_key = test_private_key.public_key
      cert.not_before = Time.now - 3600
      cert.not_after = Time.now + 3600
      cert.sign(test_private_key, OpenSSL::Digest::SHA256.new)
      cert.to_pem
    end

    let(:kid) { 'test-key-id' }
    let(:certificates) { { kid => test_certificate } }

    let(:valid_payload) do
      {
        'aud' => project_id,
        'iss' => "https://securetoken.google.com/#{project_id}",
        'sub' => firebase_uid,
        'email' => user_email,
        'iat' => Time.now.to_i - 60,
        'exp' => Time.now.to_i + 3600,
        'auth_time' => Time.now.to_i - 120
      }
    end

    let(:valid_token) do
      JWT.encode(
        valid_payload,
        test_private_key,
        'RS256',
        { kid: kid }
      )
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FIREBASE_PROJECT_ID').and_return(project_id)
      # Mock the certificate fetch
      allow(Rails.cache).to receive(:fetch).and_return(certificates)
    end

    describe '#verify' do
      it 'returns the payload for a valid token' do
        verifier = described_class.new(valid_token)
        payload = verifier.verify

        expect(payload).to be_present
        expect(payload['sub']).to eq(firebase_uid)
        expect(payload['email']).to eq(user_email)
      end

      it 'returns nil for a blank token' do
        verifier = described_class.new('')
        expect(verifier.verify).to be_nil
      end

      it 'returns nil for nil token' do
        verifier = described_class.new(nil)
        expect(verifier.verify).to be_nil
      end

      it 'returns nil when project_id is not configured' do
        allow(ENV).to receive(:[]).with('FIREBASE_PROJECT_ID').and_return(nil)
        verifier = described_class.new(valid_token)
        expect(verifier.verify).to be_nil
      end
    end

    describe '#verify!' do
      context 'with valid token' do
        it 'returns the payload' do
          verifier = described_class.new(valid_token)
          payload = verifier.verify!

          expect(payload['sub']).to eq(firebase_uid)
          expect(payload['email']).to eq(user_email)
        end
      end

      context 'with blank token' do
        it 'raises InvalidTokenError' do
          verifier = described_class.new('')
          expect { verifier.verify! }.to raise_error(
            FirebaseTokenVerifier::InvalidTokenError,
            'Token is blank'
          )
        end
      end

      context 'with invalid audience' do
        let(:invalid_aud_payload) { valid_payload.merge('aud' => 'wrong-project') }
        let(:invalid_aud_token) do
          JWT.encode(invalid_aud_payload, test_private_key, 'RS256', { kid: kid })
        end

        it 'raises InvalidAudienceError' do
          verifier = described_class.new(invalid_aud_token)
          expect { verifier.verify! }.to raise_error(
            FirebaseTokenVerifier::InvalidAudienceError
          )
        end
      end

      context 'with invalid issuer' do
        let(:invalid_iss_payload) { valid_payload.merge('iss' => 'https://wrong-issuer.com/project') }
        let(:invalid_iss_token) do
          JWT.encode(invalid_iss_payload, test_private_key, 'RS256', { kid: kid })
        end

        it 'raises InvalidIssuerError' do
          verifier = described_class.new(invalid_iss_token)
          expect { verifier.verify! }.to raise_error(
            FirebaseTokenVerifier::InvalidIssuerError
          )
        end
      end

      context 'with empty subject' do
        let(:empty_sub_payload) { valid_payload.merge('sub' => '') }
        let(:empty_sub_token) do
          JWT.encode(empty_sub_payload, test_private_key, 'RS256', { kid: kid })
        end

        it 'raises InvalidTokenError' do
          verifier = described_class.new(empty_sub_token)
          expect { verifier.verify! }.to raise_error(
            FirebaseTokenVerifier::InvalidTokenError,
            /subject.*empty/i
          )
        end
      end

      context 'with expired token' do
        let(:expired_payload) { valid_payload.merge('exp' => Time.now.to_i - 3600) }
        let(:expired_token) do
          JWT.encode(expired_payload, test_private_key, 'RS256', { kid: kid })
        end

        it 'raises JWT::ExpiredSignature' do
          verifier = described_class.new(expired_token)
          expect { verifier.verify! }.to raise_error(JWT::ExpiredSignature)
        end
      end

      context 'when certificate not found for kid' do
        let(:wrong_kid_token) do
          JWT.encode(valid_payload, test_private_key, 'RS256', { kid: 'unknown-kid' })
        end

        it 'raises CertificateError' do
          verifier = described_class.new(wrong_kid_token)
          expect { verifier.verify! }.to raise_error(
            FirebaseTokenVerifier::CertificateError,
            /No certificate found/
          )
        end
      end

      context 'with future auth_time' do
        let(:future_auth_payload) { valid_payload.merge('auth_time' => Time.now.to_i + 3600) }
        let(:future_auth_token) do
          JWT.encode(future_auth_payload, test_private_key, 'RS256', { kid: kid })
        end

        it 'raises InvalidTokenError' do
          verifier = described_class.new(future_auth_token)
          expect { verifier.verify! }.to raise_error(
            FirebaseTokenVerifier::InvalidTokenError,
            /auth_time is in the future/
          )
        end
      end
    end

    describe '.fetch_certificates!' do
      it 'fetches certificates from Google API' do
        certificates_response = { 'kid1' => 'cert1', 'kid2' => 'cert2' }.to_json
        stub_request(:get, FirebaseTokenVerifier::CERTIFICATES_URL)
          .to_return(
            status: 200,
            body: certificates_response,
            headers: { 'Cache-Control' => 'max-age=3600' }
          )

        # Don't use cached value
        allow(Rails.cache).to receive(:fetch).and_call_original

        result = described_class.fetch_certificates!

        expect(result).to eq({ 'kid1' => 'cert1', 'kid2' => 'cert2' })
      end

      it 'raises CertificateError on network failure' do
        stub_request(:get, FirebaseTokenVerifier::CERTIFICATES_URL)
          .to_return(status: 500)

        allow(Rails.cache).to receive(:fetch).and_call_original

        expect { described_class.fetch_certificates! }.to raise_error(
          FirebaseTokenVerifier::CertificateError,
          /Failed to fetch certificates/
        )
      end
    end
  end
end
