# frozen_string_literal: true

module SiteAdmin
  class DomainsController < SiteAdminController
    before_action :set_website

    def show
      # Generate verification token if custom domain set but no token
      if @website.custom_domain.present? && @website.custom_domain_verification_token.blank?
        @website.generate_domain_verification_token!
      end

      @platform_domains = Pwb::Website.platform_domains
      @platform_ip = Rails.application.config.tenant_domains[:platform_ip]
    end

    def update
      old_domain = @website.custom_domain

      if @website.update(domain_params)
        # Generate new verification token if domain changed
        if @website.custom_domain != old_domain && @website.custom_domain.present?
          @website.update!(
            custom_domain_verified: false,
            custom_domain_verified_at: nil
          )
          @website.generate_domain_verification_token!
          redirect_to site_admin_domain_path, notice: 'Custom domain updated. Please verify ownership using the DNS instructions below.'
        elsif @website.custom_domain.blank?
          redirect_to site_admin_domain_path, notice: 'Custom domain removed.'
        else
          redirect_to site_admin_domain_path, notice: 'Domain settings saved.'
        end
      else
        @platform_domains = Pwb::Website.platform_domains
        @platform_ip = Rails.application.config.tenant_domains[:platform_ip]
        render :show, status: :unprocessable_entity
      end
    end

    def verify
      if @website.custom_domain.blank?
        redirect_to site_admin_domain_path, alert: 'No custom domain configured.'
        return
      end

      if @website.verify_custom_domain!
        redirect_to site_admin_domain_path, notice: 'Domain verified successfully! Your custom domain is now active.'
      else
        redirect_to site_admin_domain_path, alert: 'Domain verification failed. Please ensure you have added the correct DNS TXT record and wait for DNS propagation (can take up to 48 hours).'
      end
    end

    private

    def set_website
      @website = current_website
    end

    def domain_params
      params.require(:website).permit(:custom_domain)
    end
  end
end
