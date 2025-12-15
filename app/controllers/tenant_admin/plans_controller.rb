# frozen_string_literal: true

module TenantAdmin
  class PlansController < TenantAdminController
    before_action :set_plan, only: [:show, :edit, :update, :destroy]

    def index
      @plans = Pwb::Plan.order(position: :asc)

      # Filter by active status
      if params[:active].present?
        @plans = @plans.where(active: params[:active] == 'true')
      end

      # Search by name
      if params[:search].present?
        @plans = @plans.where("name ILIKE ? OR display_name ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
      end

      @stats = {
        total: Pwb::Plan.count,
        active: Pwb::Plan.active.count,
        public: Pwb::Plan.public_plans.count,
        subscriptions: Pwb::Subscription.count
      }
    end

    def show
      @subscriptions = @plan.subscriptions.includes(:website).order(created_at: :desc).limit(10)
    end

    def new
      @plan = Pwb::Plan.new(
        active: true,
        public: true,
        billing_interval: 'month',
        price_currency: 'USD',
        trial_days: 14,
        position: Pwb::Plan.maximum(:position).to_i + 1
      )
    end

    def create
      @plan = Pwb::Plan.new(plan_params)

      if @plan.save
        redirect_to tenant_admin_plan_path(@plan), notice: "Plan '#{@plan.display_name}' created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # @plan set by before_action
    end

    def update
      if @plan.update(plan_params)
        redirect_to tenant_admin_plan_path(@plan), notice: "Plan '#{@plan.display_name}' updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @plan.subscriptions.any?
        redirect_to tenant_admin_plans_path, alert: "Cannot delete plan with active subscriptions. Reassign subscriptions first."
      else
        @plan.destroy
        redirect_to tenant_admin_plans_path, notice: "Plan '#{@plan.display_name}' deleted successfully."
      end
    end

    private

    def set_plan
      @plan = Pwb::Plan.find(params[:id])
    end

    def plan_params
      params.require(:pwb_plan).permit(
        :name,
        :slug,
        :display_name,
        :description,
        :price_cents,
        :price_currency,
        :billing_interval,
        :trial_days,
        :property_limit,
        :user_limit,
        :active,
        :public,
        :position,
        features: []
      )
    end
  end
end
