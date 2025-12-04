# frozen_string_literal: true

# SiteAdminHelper
# Helper methods for site admin views
module SiteAdminHelper
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
    direction = (column == params[:sort] && params[:direction] == 'asc') ? 'desc' : 'asc'
    link_to title, { sort: column, direction: direction }, class: 'text-blue-600 hover:text-blue-800'
  end
end
