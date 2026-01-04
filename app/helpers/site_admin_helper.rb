# frozen_string_literal: true

# SiteAdminHelper
# Helper methods for site admin views
module SiteAdminHelper
  # Pagy 43.x: Frontend helpers are now instance methods on @pagy object
  # Format date consistently
  def format_date(date)
    return 'N/A' if date.blank?

    date.strftime('%Y-%m-%d %H:%M')
  end

  def tab_link_class(tab_name, current_category)
    base_classes = "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"
    if current_category == tab_name
      "#{base_classes} border-blue-500 text-blue-600"
    else
      "#{base_classes} border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end

  # Generate link to property
  def property_link(property)
    link_to property.title || property.reference,
            site_admin_prop_path(property),
            class: 'text-blue-600 hover:text-blue-800'
  end

  # Generate link to page
  def page_link(page)
    link_to page.slug,
            site_admin_page_path(page),
            class: 'text-blue-600 hover:text-blue-800'
  end

  # Generate link to user
  def user_link(user)
    link_to user.email,
            site_admin_user_path(user),
            class: 'text-blue-600 hover:text-blue-800'
  end

  # Map flash types to Tailwind CSS classes
  def flash_class(type)
    case type.to_sym
    when :notice
      'bg-blue-100 border-blue-500 text-blue-700'
    when :success
      'bg-green-100 border-green-500 text-green-700'
    when :alert
      'bg-red-100 border-red-500 text-red-700'
    when :warning
      'bg-yellow-100 border-yellow-500 text-yellow-700'
    else
      'bg-gray-100 border-gray-500 text-gray-700'
    end
  end

  # Render status badge
  def badge_for_status(active)
    if active
      content_tag(:span, 'Active', class: 'px-2 py-1 text-xs rounded bg-green-100 text-green-800')
    else
      content_tag(:span, 'Inactive', class: 'px-2 py-1 text-xs rounded bg-gray-100 text-gray-800')
    end
  end

  # Helper for sortable column headers
  def sortable_column(column, title = nil)
    title ||= column.titleize
    direction = column == params[:sort] && params[:direction] == 'asc' ? 'desc' : 'asc'
    link_to title, { sort: column, direction: direction }, class: 'text-blue-600 hover:text-blue-800'
  end

  # Get human-readable locale name
  #
  # @param locale [Symbol, String] The locale code
  # @return [String] Human-readable locale name
  def locale_name(locale)
    locale_names = {
      'en' => 'English',
      'es' => 'Spanish',
      'fr' => 'French',
      'de' => 'German',
      'it' => 'Italian',
      'pt' => 'Portuguese',
      'nl' => 'Dutch',
      'ru' => 'Russian',
      'tr' => 'Turkish',
      'ar' => 'Arabic',
      'zh' => 'Chinese',
      'ja' => 'Japanese'
    }
    locale_names[locale.to_s] || locale.to_s.upcase
  end

  # Sidebar navigation helpers
  # Determine which sidebar section contains the current page
  # Used for smart auto-expand behavior
  def current_nav_section
    path = request.path
    tab = params[:tab]

    # Listings section
    return 'listings' if path.include?('/props') ||
                         path.include?('/property_import_export') ||
                         path.include?('/external_feed') ||
                         path.include?('/properties_settings') ||
                         path.include?('/widgets') ||
                         tab == 'search'

    # Leads & Messages section
    return 'leads' if path.include?('/inbox') ||
                      path.include?('/messages') ||
                      path.include?('/contacts') ||
                      path.include?('/email_templates')

    # Analytics section
    return 'analytics' if path.include?('/analytics') ||
                          path.include?('/activity_logs')

    # Settings section
    return 'settings' if path.include?('/users') ||
                         path.include?('/agency') ||
                         path.include?('/billing') ||
                         path.include?('/domain') ||
                         path.include?('/onboarding') ||
                         path.include?('/storage_stats') ||
                         path.include?('/support_tickets') ||
                         tab.in?(%w[general notifications social])

    # Site Design section
    return 'siteDesign' if path.include?('/pages') ||
                           path.include?('/media_library') ||
                           path.include?('/seo_audit') ||
                           tab.in?(%w[appearance navigation seo])

    nil
  end

  # Breadcrumb helpers
  # Set breadcrumbs for current page
  # @param breadcrumbs [Array<Hash>] Array of {label: String, url: String}
  # @example
  #   set_breadcrumbs(
  #     { label: 'Properties', url: site_admin_props_path },
  #     { label: @prop.reference, url: site_admin_prop_path(@prop) }
  #   )
  def set_breadcrumbs(*breadcrumbs)
    @breadcrumbs = breadcrumbs
  end

  # Add a single breadcrumb to existing trail
  def add_breadcrumb(label, url = nil)
    @breadcrumbs ||= []
    @breadcrumbs << { label: label, url: url }
  end

  # Get breadcrumbs, auto-generating if not set
  def breadcrumbs
    @breadcrumbs || auto_breadcrumbs
  end

  # Auto-generate breadcrumbs based on controller/action
  def auto_breadcrumbs
    return [] if controller_name == 'dashboard'

    crumbs = []

    # Map controller names to section info
    section_map = {
      'props' => { section: 'Listings', label: 'Properties', url: :site_admin_props_path },
      'property_import_export' => { section: 'Listings', label: 'Import/Export', url: :site_admin_property_import_export_path },
      'external_feeds' => { section: 'Listings', label: 'External Feeds', url: :site_admin_external_feed_path },
      'widgets' => { section: 'Listings', label: 'Embed Widgets', url: :site_admin_widgets_path },
      'inbox' => { section: 'Leads & Messages', label: 'Inbox', url: :site_admin_inbox_index_path },
      'messages' => { section: 'Leads & Messages', label: 'Messages', url: :site_admin_messages_path },
      'contacts' => { section: 'Leads & Messages', label: 'Contacts', url: :site_admin_contacts_path },
      'email_templates' => { section: 'Leads & Messages', label: 'Email Templates', url: :site_admin_email_templates_path },
      'support_tickets' => { section: 'Settings', label: 'Support', url: :site_admin_support_tickets_path },
      'analytics' => { section: 'Analytics', label: 'Analytics', url: :site_admin_analytics_path },
      'activity_logs' => { section: 'Analytics', label: 'Activity Logs', url: :site_admin_activity_logs_path },
      'users' => { section: 'Settings', label: 'Team & Users', url: :site_admin_users_path },
      'agency' => { section: 'Settings', label: 'Agency Profile', url: :edit_site_admin_agency_path },
      'billing' => { section: 'Settings', label: 'Billing', url: :site_admin_billing_path },
      'domains' => { section: 'Settings', label: 'Domain', url: :site_admin_domain_path },
      'onboarding' => { section: 'Settings', label: 'Setup Wizard', url: :site_admin_onboarding_path },
      'storage_stats' => { section: 'Settings', label: 'Storage Stats', url: :site_admin_storage_stats_path },
      'pages' => { section: 'Site Design', label: 'Pages', url: :site_admin_pages_path },
      'media_library' => { section: 'Site Design', label: 'Media Library', url: :site_admin_media_library_index_path },
      'seo_audit' => { section: 'Site Design', label: 'SEO Audit', url: :site_admin_seo_audit_path }
    }

    info = section_map[controller_name]
    return [] unless info

    # Add section breadcrumb
    crumbs << { label: info[:section], url: nil }

    # Add controller-level breadcrumb for index
    if action_name == 'index'
      crumbs << { label: info[:label], url: nil }
    else
      # Link to index for non-index actions
      crumbs << { label: info[:label], url: send(info[:url]) }

      # Add action-level breadcrumb
      action_labels = {
        'show' => 'View',
        'edit' => 'Edit',
        'new' => 'New'
      }
      if action_labels[action_name]
        crumbs << { label: action_labels[action_name], url: nil }
      end
    end

    crumbs
  end
end
