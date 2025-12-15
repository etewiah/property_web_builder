# frozen_string_literal: true

module TenantAdmin
  class SubscriptionsController < TenantAdminController
    before_action :set_subscription, only: [:show, :edit, :update, :destroy, :activate, :cancel, :change_plan]

    def index
      @subscriptions = Pwb::Subscription.includes(:website, :plan).order(created_at: :desc)

      # Filter by status
      if params[:status].present?
        @subscriptions = @subscriptions.where(status: params[:status])
      end

      # Filter by plan
      if params[:plan_id].present?
        @subscriptions = @subscriptions.where(plan_id: params[:plan_id])
      end

      # Search by website subdomain
      if params[:search].present?
        @subscriptions = @subscriptions.joins(:website).where(
          "pwb_websites.subdomain ILIKE ?",
          "%#{params[:search]}%"
        )
      end

      @pagy, @subscriptions = pagy(@subscriptions, limit: 20)

      @stats = {
        total: Pwb::Subscription.count,
        active: Pwb::Subscription.active_subscriptions.count,
        trialing: Pwb::Subscription.trialing.count,
        past_due: Pwb::Subscription.past_due.count,
        canceled: Pwb::Subscription.canceled.count
      }

      @plans = Pwb::Plan.active.ordered
    end

    def show
      @events = @subscription.events.order(created_at: :desc).limit(20)
    end

    def new
      @subscription = Pwb::Subscription.new
      @websites = Pwb::Website.unscoped.where.not(id: Pwb::Subscription.select(:website_id)).order(:subdomain)
      @plans = Pwb::Plan.active.ordered
    end

    def create
      @subscription = Pwb::Subscription.new(subscription_params)

      if @subscription.save
        # Start trial if plan has trial days
        if @subscription.plan.trial_days > 0
          @subscription.start_trial
        else
          @subscription.activate! if @subscription.may_activate?
        end

        redirect_to tenant_admin_subscription_path(@subscription), notice: "Subscription created successfully."
      else
        @websites = Pwb::Website.unscoped.where.not(id: Pwb::Subscription.select(:website_id)).order(:subdomain)
        @plans = Pwb::Plan.active.ordered
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @plans = Pwb::Plan.active.ordered
    end

    def update
      if @subscription.update(subscription_params)
        redirect_to tenant_admin_subscription_path(@subscription), notice: "Subscription updated successfully."
      else
        @plans = Pwb::Plan.active.ordered
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      website = @subscription.website
      @subscription.destroy
      redirect_to tenant_admin_subscriptions_path, notice: "Subscription for '#{website.subdomain}' deleted."
    end

    # Manually activate a subscription
    def activate
      if @subscription.may_activate?
        @subscription.activate!
        redirect_to tenant_admin_subscription_path(@subscription), notice: "Subscription activated."
      else
        redirect_to tenant_admin_subscription_path(@subscription), alert: "Cannot activate subscription in '#{@subscription.status}' status."
      end
    end

    # Manually cancel a subscription
    def cancel
      if @subscription.may_cancel?
        @subscription.cancel!
        redirect_to tenant_admin_subscription_path(@subscription), notice: "Subscription canceled."
      else
        redirect_to tenant_admin_subscription_path(@subscription), alert: "Cannot cancel subscription in '#{@subscription.status}' status."
      end
    end

    # Change subscription plan
    def change_plan
      new_plan = Pwb::Plan.find(params[:new_plan_id])

      if @subscription.change_plan(new_plan)
        redirect_to tenant_admin_subscription_path(@subscription), notice: "Plan changed to '#{new_plan.display_name}'."
      else
        redirect_to tenant_admin_subscription_path(@subscription), alert: "Failed to change plan."
      end
    end

    # Bulk expire trials
    def expire_trials
      count = Pwb::Subscription.trial_expired.count
      Pwb::Subscription.trial_expired.find_each do |sub|
        sub.expire_trial! if sub.may_expire_trial?
      end
      redirect_to tenant_admin_subscriptions_path, notice: "Expired #{count} trial subscriptions."
    end

    private

    def set_subscription
      @subscription = Pwb::Subscription.find(params[:id])
    end

    def subscription_params
      params.require(:pwb_subscription).permit(
        :website_id,
        :plan_id,
        :status,
        :trial_ends_at,
        :current_period_starts_at,
        :current_period_ends_at,
        :cancel_at_period_end,
        :external_id,
        :external_customer_id
      )
    end
  end
end
