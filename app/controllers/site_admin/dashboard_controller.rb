# frozen_string_literal: true

module SiteAdmin
  # DashboardController
  # Main dashboard for site administration
  # Shows statistics and recent activity for the current website/tenant
  class DashboardController < SiteAdminController
    def index
      @website = current_website
      website_id = current_website.id

      # Statistics for current website - scoped by website_id for multi-tenant isolation
      # Use Pwb::ListedProperty (materialized view) for property counts
      @stats = {
        total_properties: Pwb::ListedProperty.where(website_id: website_id).count,
        total_pages: Pwb::Page.where(website_id: website_id).count,
        total_contents: Pwb::Content.where(website_id: website_id).count,
        total_messages: Pwb::Message.where(website_id: website_id).count,
        total_contacts: Pwb::Contact.where(website_id: website_id).count
      }

      # Enhanced statistics - this week's activity
      week_start = Time.current.beginning_of_week
      @weekly_stats = {
        new_messages: Pwb::Message.where(website_id: website_id).where('created_at >= ?', week_start).count,
        new_contacts: Pwb::Contact.where(website_id: website_id).where('created_at >= ?', week_start).count,
        new_properties: Pwb::ListedProperty.where(website_id: website_id).where('created_at >= ?', week_start).count
      }

      # Unread messages count
      @unread_messages_count = Pwb::Message.where(website_id: website_id).where(read: false).count

      # Recent activity for current website - scoped by website_id for multi-tenant isolation
      # Use Pwb::ListedProperty (materialized view) for property listing
      @recent_properties = Pwb::ListedProperty.where(website_id: website_id).order(created_at: :desc).limit(5)
      @recent_messages = Pwb::Message.where(website_id: website_id).order(created_at: :desc).limit(5)
      @recent_contacts = Pwb::Contact.where(website_id: website_id).order(created_at: :desc).limit(5)

      # Combined activity timeline (last 10 items)
      @activity_timeline = build_activity_timeline(website_id)

      # Website health/setup checklist
      @website_health = calculate_website_health(website_id)

      # Subscription information for current website
      @subscription = Pwb::Subscription.find_by(website_id: website_id)
      if @subscription
        @subscription_info = {
          status: @subscription.status,
          plan_name: @subscription.plan.display_name,
          plan_price: @subscription.plan.formatted_price,
          trial_days_remaining: @subscription.trial_days_remaining,
          trial_ending_soon: @subscription.trial_ending_soon?,
          in_good_standing: @subscription.in_good_standing?,
          allows_access: @subscription.allows_access?,
          current_period_ends_at: @subscription.current_period_ends_at,
          property_limit: @subscription.plan.property_limit,
          remaining_properties: @subscription.remaining_properties,
          user_limit: @subscription.plan.user_limit,
          remaining_users: @subscription.remaining_users,
          features: @subscription.plan.enabled_features,
          cancel_at_period_end: @subscription.cancel_at_period_end?
        }

        # Usage data for meters
        @usage = {
          properties: {
            current: @stats[:total_properties],
            limit: @subscription.plan.property_limit,
            unlimited: @subscription.plan.unlimited_properties?
          },
          users: {
            current: current_website.users.count,
            limit: @subscription.plan.user_limit,
            unlimited: @subscription.plan.unlimited_users?
          }
        }
      end

      # Show getting started guide only for new users
      @show_getting_started = should_show_getting_started?
    end

    private

    def build_activity_timeline(website_id)
      activities = []

      # Get recent messages
      Pwb::Message.where(website_id: website_id)
                  .order(created_at: :desc)
                  .limit(5)
                  .each do |msg|
        activities << {
          type: :message,
          icon: 'email',
          title: "New message from #{msg.origin_email.presence || 'Unknown'}",
          time: msg.created_at,
          path: site_admin_message_path(msg)
        }
      end

      # Get recent properties
      Pwb::ListedProperty.where(website_id: website_id)
                         .order(created_at: :desc)
                         .limit(5)
                         .each do |prop|
        activities << {
          type: :property,
          icon: 'property',
          title: "Property \"#{prop.title.presence || prop.reference}\" was created",
          time: prop.created_at,
          path: site_admin_prop_path(prop)
        }
      end

      # Get recent contacts
      Pwb::Contact.where(website_id: website_id)
                  .order(created_at: :desc)
                  .limit(5)
                  .each do |contact|
        activities << {
          type: :contact,
          icon: 'contact',
          title: "New contact: #{contact.first_name.presence || contact.primary_email.presence || 'Unknown'}",
          time: contact.created_at,
          path: site_admin_contact_path(contact)
        }
      end

      # Sort by time and take latest 10
      activities.sort_by { |a| a[:time] }.reverse.first(10)
    end

    def calculate_website_health(website_id)
      checks = []
      agency = @website&.agency

      # Agency profile complete
      agency_complete = agency.present? &&
                        agency.company_name.present? &&
                        agency.email_primary.present?
      checks << {
        name: 'Agency profile complete',
        complete: agency_complete,
        path: edit_site_admin_agency_path,
        priority: :high
      }

      # At least one property
      has_properties = @stats[:total_properties] > 0
      checks << {
        name: 'At least one property added',
        complete: has_properties,
        path: new_site_admin_prop_path,
        priority: :high
      }

      # Theme configured (has a non-default theme or customized)
      theme_configured = @website&.theme_name.present?
      checks << {
        name: 'Theme configured',
        complete: theme_configured,
        path: site_admin_website_settings_tab_path('appearance'),
        priority: :medium
      }

      # Custom domain set up
      domain_configured = @website&.custom_domain.present?
      checks << {
        name: 'Custom domain configured',
        complete: domain_configured,
        path: site_admin_domain_path,
        priority: :low
      }

      # Social media links
      social_links = Pwb::Link.where(website_id: website_id)
                              .where("slug LIKE 'social_%'")
                              .where(visible: true)
                              .count
      has_social = social_links > 0
      checks << {
        name: 'Social media links added',
        complete: has_social,
        path: site_admin_website_settings_tab_path('social'),
        priority: :low
      }

      # SEO configured
      seo_configured = @website&.default_seo_title.present? || @website&.default_meta_description.present?
      checks << {
        name: 'SEO meta tags configured',
        complete: seo_configured,
        path: site_admin_website_settings_tab_path('seo'),
        priority: :medium
      }

      # Logo uploaded
      has_logo = @website&.main_logo_url.present?
      checks << {
        name: 'Logo uploaded',
        complete: has_logo,
        path: site_admin_website_settings_tab_path('seo'),
        priority: :medium
      }

      completed_count = checks.count { |c| c[:complete] }
      total_count = checks.size
      percentage = total_count > 0 ? (completed_count.to_f / total_count * 100).round : 0

      {
        checks: checks,
        completed: completed_count,
        total: total_count,
        percentage: percentage
      }
    end

    def should_show_getting_started?
      return false if cookies[:dismiss_getting_started] == 'true'

      # Show if website health is below 70% or has few properties
      @website_health[:percentage] < 70 || @stats[:total_properties] < 3
    end
  end
end
