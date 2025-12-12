# frozen_string_literal: true

module TenantAdmin
  class DomainsController < TenantAdminController
    before_action :set_website, only: [:show, :edit, :update, :verify, :remove]

    def index
      # Get all websites with custom domains configured
      @websites_with_domains = Pwb::Website.unscoped
                                           .where.not(custom_domain: [nil, ''])
                                           .order(custom_domain_verified_at: :desc, created_at: :desc)

      # Filter by verification status
      if params[:status].present?
        case params[:status]
        when 'verified'
          @websites_with_domains = @websites_with_domains.where(custom_domain_verified: true)
        when 'pending'
          @websites_with_domains = @websites_with_domains.where(custom_domain_verified: [false, nil])
        end
      end

      # Search
      if params[:search].present?
        @websites_with_domains = @websites_with_domains.where(
          "custom_domain ILIKE ? OR subdomain ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end

      @pagy, @websites_with_domains = pagy(@websites_with_domains, limit: 20)

      # Statistics
      @stats = {
        total: Pwb::Website.unscoped.where.not(custom_domain: [nil, '']).count,
        verified: Pwb::Website.unscoped.where(custom_domain_verified: true).count,
        pending: Pwb::Website.unscoped.where.not(custom_domain: [nil, '']).where(custom_domain_verified: [false, nil]).count
      }

      # Get websites without custom domains that could benefit from one
      @websites_without_domains = Pwb::Website.unscoped
                                              .where(custom_domain: [nil, ''])
                                              .where(provisioning_state: 'live')
                                              .order(created_at: :desc)
                                              .limit(5)
    end

    def show
      # @website set by before_action
    end

    def edit
      # @website set by before_action
      # Generate verification token if not present
      @website.generate_domain_verification_token! if @website.custom_domain_verification_token.blank?
    end

    def update
      old_domain = @website.custom_domain

      if @website.update(domain_params)
        # Reset verification if domain changed
        if old_domain != @website.custom_domain && @website.custom_domain.present?
          @website.update(
            custom_domain_verified: false,
            custom_domain_verified_at: nil
          )
          @website.generate_domain_verification_token!
          redirect_to edit_tenant_admin_domain_path(@website), notice: "Custom domain updated. Please verify ownership."
        else
          redirect_to tenant_admin_domain_path(@website), notice: "Domain settings updated successfully."
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Trigger DNS verification
    def verify
      if @website.custom_domain.blank?
        redirect_to tenant_admin_domains_path, alert: "No custom domain configured."
        return
      end

      if @website.verify_custom_domain!
        redirect_to tenant_admin_domain_path(@website), notice: "Domain verified successfully!"
      else
        redirect_to edit_tenant_admin_domain_path(@website), alert: "Domain verification failed. Please check your DNS settings."
      end
    end

    # Remove custom domain from website
    def remove
      @website.update(
        custom_domain: nil,
        custom_domain_verification_token: nil,
        custom_domain_verified: false,
        custom_domain_verified_at: nil
      )
      redirect_to tenant_admin_domains_path, notice: "Custom domain removed from #{@website.subdomain}."
    end

    private

    def set_website
      @website = Pwb::Website.unscoped.find(params[:id])
    end

    def domain_params
      params.require(:website).permit(:custom_domain)
    end
  end
end
