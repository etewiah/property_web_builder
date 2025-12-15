# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Pwb::LockedController", type: :request do
  let(:owner_email) { "owner@example.com" }

  describe "GET /resend_verification" do
    context "when website is locked pending email verification" do
      let!(:website) do
        create(:pwb_website,
               subdomain: "test-locked",
               provisioning_state: 'locked_pending_email_verification',
               owner_email: owner_email)
      end

      it "renders the resend verification form" do
        host! "test-locked.example.com"
        get "/resend_verification"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Resend Verification Email")
        expect(response.body).to include("Enter the email address")
      end
    end

    context "when website is not locked" do
      let!(:website) do
        create(:pwb_website,
               subdomain: "test-live",
               provisioning_state: 'live')
      end

      it "redirects to root" do
        host! "test-live.example.com"
        get "/resend_verification"

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/")
      end
    end
  end

  describe "POST /resend_verification" do
    context "when website is locked pending email verification" do
      let!(:website) do
        create(:pwb_website,
               subdomain: "test-locked",
               provisioning_state: 'locked_pending_email_verification',
               owner_email: owner_email,
               email_verification_token: SecureRandom.urlsafe_base64(32),
               email_verification_token_expires_at: 7.days.from_now)
      end

      it "sends verification email when email matches" do
        host! "test-locked.example.com"

        expect {
          post "/resend_verification", params: { email: owner_email }
        }.to have_enqueued_mail(Pwb::EmailVerificationMailer, :verification_email)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Verification email sent")
      end

      it "shows error when email is blank" do
        host! "test-locked.example.com"
        post "/resend_verification", params: { email: "" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Please enter your email address")
      end

      it "shows error when email is invalid" do
        host! "test-locked.example.com"
        post "/resend_verification", params: { email: "invalid-email" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Please enter a valid email address")
      end

      it "shows error when email doesn't match owner email" do
        host! "test-locked.example.com"
        post "/resend_verification", params: { email: "wrong@example.com" }

        expect(response).to have_http_status(:ok)
        # The apostrophe may be HTML-escaped, so we check for the key part of the message
        expect(response.body).to include("match our records")
      end

      it "is case insensitive for email matching" do
        host! "test-locked.example.com"

        expect {
          post "/resend_verification", params: { email: "OWNER@EXAMPLE.COM" }
        }.to have_enqueued_mail(Pwb::EmailVerificationMailer, :verification_email)

        expect(response.body).to include("Verification email sent")
      end
    end

    context "when website is locked pending registration (already verified)" do
      let!(:website) do
        create(:pwb_website,
               subdomain: "test-verified",
               provisioning_state: 'locked_pending_registration',
               owner_email: owner_email)
      end

      it "shows error that email is already verified" do
        host! "test-verified.example.com"
        post "/resend_verification", params: { email: owner_email }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("already been verified")
      end
    end

    context "when website is live" do
      let!(:website) do
        create(:pwb_website,
               subdomain: "test-live",
               provisioning_state: 'live',
               owner_email: owner_email)
      end

      it "redirects to root" do
        host! "test-live.example.com"
        post "/resend_verification", params: { email: owner_email }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/")
      end
    end
  end
end
