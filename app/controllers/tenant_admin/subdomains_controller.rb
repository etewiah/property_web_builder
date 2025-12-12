# frozen_string_literal: true

module TenantAdmin
  class SubdomainsController < TenantAdminController
    before_action :set_subdomain, only: [:show, :edit, :update, :destroy, :release]

    def index
      @subdomains = Pwb::Subdomain.includes(:website).order(created_at: :desc)

      # Filter by state
      if params[:state].present?
        @subdomains = @subdomains.where(aasm_state: params[:state])
      end

      # Search by name or email
      if params[:search].present?
        @subdomains = @subdomains.where(
          "name ILIKE ? OR reserved_by_email ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end

      @pagy, @subdomains = pagy(@subdomains, limit: 20)

      # Statistics for the dashboard cards
      @stats = {
        total: Pwb::Subdomain.count,
        available: Pwb::Subdomain.available.count,
        reserved: Pwb::Subdomain.reserved.count,
        allocated: Pwb::Subdomain.allocated.count,
        expired_reservations: Pwb::Subdomain.expired_reservations.count
      }

      # Get pending signups (users with reserved subdomains but no website yet)
      @pending_signups = pending_signups_data
    end

    def show
      # @subdomain set by before_action
    end

    def new
      @subdomain = Pwb::Subdomain.new
    end

    def create
      @subdomain = Pwb::Subdomain.new(subdomain_params)

      if @subdomain.save
        redirect_to tenant_admin_subdomain_path(@subdomain), notice: "Subdomain created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # @subdomain set by before_action
    end

    def update
      if @subdomain.update(subdomain_params)
        redirect_to tenant_admin_subdomain_path(@subdomain), notice: "Subdomain updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @subdomain.destroy
      redirect_to tenant_admin_subdomains_path, notice: "Subdomain deleted successfully."
    end

    # Release a reserved or allocated subdomain
    def release
      if @subdomain.may_release?
        @subdomain.release!
        @subdomain.make_available! if @subdomain.may_make_available?
        redirect_to tenant_admin_subdomains_path, notice: "Subdomain '#{@subdomain.name}' released and made available."
      else
        redirect_to tenant_admin_subdomains_path, alert: "Cannot release subdomain in '#{@subdomain.aasm_state}' state."
      end
    end

    # Bulk release expired reservations
    def release_expired
      count = Pwb::Subdomain.expired_reservations.count
      Pwb::Subdomain.release_expired!
      redirect_to tenant_admin_subdomains_path, notice: "Released #{count} expired reservations."
    end

    # Populate subdomain pool
    def populate
      count = params[:count].to_i
      count = 50 if count <= 0 || count > 500

      created = 0
      count.times do
        name = Pwb::SubdomainGenerator.generate
        subdomain = Pwb::Subdomain.new(name: name, aasm_state: 'available')
        created += 1 if subdomain.save
      end

      redirect_to tenant_admin_subdomains_path, notice: "Created #{created} new subdomains."
    end

    private

    def set_subdomain
      @subdomain = Pwb::Subdomain.find(params[:id])
    end

    def subdomain_params
      params.require(:subdomain).permit(:name, :aasm_state)
    end

    # Get data about users who have reserved subdomains during signup
    def pending_signups_data
      # Find reserved subdomains with email addresses
      reserved_subdomains = Pwb::Subdomain.reserved
                                          .where.not(reserved_by_email: nil)
                                          .order(reserved_at: :desc)

      reserved_subdomains.map do |subdomain|
        user = Pwb::User.unscoped.find_by(email: subdomain.reserved_by_email)
        {
          subdomain: subdomain,
          user: user,
          email: subdomain.reserved_by_email,
          reserved_at: subdomain.reserved_at,
          expires_at: subdomain.reserved_until,
          expired: subdomain.reserved_until.present? && subdomain.reserved_until < Time.current,
          has_website: user&.websites&.any?
        }
      end
    end
  end
end
