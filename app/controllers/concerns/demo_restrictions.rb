# frozen_string_literal: true

module DemoRestrictions
  extend ActiveSupport::Concern

  included do
    before_action :restrict_demo_actions, if: :demo_website?
  end

  private

  def demo_website?
    current_website&.respond_to?(:demo?) && current_website.demo?
  end

  def restrict_demo_actions
    return unless restricted_action?

    flash[:alert] = I18n.t('demo_mode.action_restricted', default: 'This action is disabled in demo mode')
    redirect_back(fallback_location: root_path)
  end

  def restricted_action?
    restricted_actions = %w[destroy delete remove purge export reset]
    restricted_actions.include?(action_name)
  end
end
