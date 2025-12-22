# frozen_string_literal: true

# SignupStatusPresenter
#
# Builds structured status responses for the signup API.
# Encapsulates the logic for determining signup stage and building
# appropriate response data for each stage.
#
class SignupStatusPresenter
  attr_reader :user, :signup_token

  def initialize(user:, signup_token:)
    @user = user
    @signup_token = signup_token
  end

  def to_h
    if website
      provisioning_status
    elsif reserved_subdomain
      subdomain_reserved_status
    else
      email_captured_status
    end
  end

  private

  def website
    @website ||= user.websites.first
  end

  def reserved_subdomain
    @reserved_subdomain ||= Pwb::Subdomain.find_by(
      reserved_by_email: user.email,
      aasm_state: 'reserved'
    )
  end

  def provisioning_status
    data = {
      signup_token: signup_token,
      stage: 'provisioning',
      email: user.email,
      subdomain: website.subdomain,
      provisioning_status: website.provisioning_state,
      progress: website.provisioning_progress,
      message: website.provisioning_status_message,
      complete: website.live?,
      website_url: website.live? ? website.primary_url : nil,
      admin_url: website.live? ? "#{website.primary_url}/site_admin" : nil
    }

    add_locked_state_info(data) if website.locked?
    data
  end

  def add_locked_state_info(data)
    data[:locked] = true
    data[:locked_mode] = website.locked_mode
    data[:email_verified] = website.email_verified?
    data[:registration_url] = "#{website.primary_url}/pwb_sign_up"
  end

  def subdomain_reserved_status
    {
      signup_token: signup_token,
      stage: 'subdomain_reserved',
      email: user.email,
      subdomain: reserved_subdomain.name,
      provisioning_status: 'pending',
      progress: 10,
      message: 'Subdomain reserved. Please configure your site.',
      complete: false,
      next_step: 'configure'
    }
  end

  def email_captured_status
    {
      signup_token: signup_token,
      stage: 'email_captured',
      email: user.email,
      subdomain: nil,
      provisioning_status: 'pending',
      progress: 5,
      message: 'Email captured. Please choose a subdomain.',
      complete: false,
      next_step: 'configure'
    }
  end
end
