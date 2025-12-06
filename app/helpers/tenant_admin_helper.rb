# frozen_string_literal: true

module TenantAdminHelper
  include Pagy::Frontend
  # Format date in a consistent way
  def format_date(date)
    return "N/A" if date.blank?
    date.strftime("%b %d, %Y %H:%M")
  end

  # Link to website show page
  def website_link(website)
    return "N/A" unless website
    link_to website.subdomain || "(No subdomain)", tenant_admin_website_path(website), class: "text-primary-600 hover:underline"
  end

  # Link to user show page
  def user_link(user)
    return "N/A" unless user
    link_to user.email, tenant_admin_user_path(user), class: "text-primary-600 hover:underline"
  end

  # Map flash types to Flowbite alert classes
  def flash_class(type)
    case type.to_sym
    when :notice
      'bg-blue-100 border-blue-500 text-blue-700'
    when :success
      'bg-green-100 border-green-500 text-green-700'
    when :alert, :error
      'bg-red-100 border-red-500 text-red-700'
    when :warning
      'bg-yellow-100 border-yellow-500 text-yellow-700'
    else
      'bg-gray-100 border-gray-500 text-gray-700'
    end
  end

  # Status badge
  def badge_for_status(active)
    if active
      content_tag(:span, "Active", class: "bg-green-100 text-green-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded")
    else
      content_tag(:span, "Inactive", class: "bg-gray-100 text-gray-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded")
    end
  end

  # Sortable column helper
  def sortable_column(column, title = nil)
    title ||= column.titleize
    direction = (params[:sort] == column && params[:direction] == "asc") ? "desc" : "asc"
    link_to title, { sort: column, direction: direction }, class: "hover:underline"
  end
end
