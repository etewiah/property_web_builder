# frozen_string_literal: true

# Error raised when tenant context (current_website) is missing
class TenantContextError < StandardError; end

# SiteAdminIndexable
#
# Provides common index/show functionality for site admin controllers
# that manage website-scoped resources with search capabilities.
#
# Usage:
#   class ContactsController < SiteAdminController
#     include SiteAdminIndexable
#
#     indexable_config model: Pwb::Contact,
#                      search_columns: [:primary_email, :first_name, :last_name],
#                      order: { created_at: :desc },
#                      limit: 100
#   end
#
# This will automatically provide:
#   - index action with website scoping and search
#   - show action with website scoping
#   - @contacts / @contact instance variables (derived from model name)
#
module SiteAdminIndexable
  extend ActiveSupport::Concern

  included do
    class_attribute :indexable_model_class
    class_attribute :indexable_search_columns, default: []
    class_attribute :indexable_order, default: { created_at: :desc }
    class_attribute :indexable_limit, default: nil
    class_attribute :indexable_includes, default: []
  end

  class_methods do
    # Configure the indexable behavior for this controller
    #
    # @param model [Class] The model class to query (e.g., Pwb::Contact)
    # @param search_columns [Array<Symbol>] Columns to search with ILIKE
    # @param order [Hash] Order clause (default: { created_at: :desc })
    # @param limit [Integer, nil] Optional limit on results
    # @param includes [Array<Symbol>] Associations to eager load
    #
    def indexable_config(model:, search_columns: [], order: { created_at: :desc }, limit: nil, includes: [])
      self.indexable_model_class = model
      self.indexable_search_columns = Array(search_columns)
      self.indexable_order = order
      self.indexable_limit = limit
      self.indexable_includes = Array(includes)
    end
  end

  # Standard index action with website scoping and search
  def index
    scope = base_index_scope
    scope = apply_search(scope) if params[:search].present?
    set_collection_variable(scope)
  end

  # Standard show action with website scoping
  def show
    set_resource_variable(find_scoped_resource)
  end

  private

  # Ensures website context exists before executing tenant-scoped queries.
  # Raises an error if current_website is nil to prevent silent failures.
  def require_website_context!
    return if current_website.present?

    raise TenantContextError, 'Website context required for this operation'
  end

  # Build the base query scope for index
  def base_index_scope
    require_website_context!
    scope = indexable_model_class.where(website_id: current_website.id)
    scope = scope.includes(*indexable_includes) if indexable_includes.any?
    scope = scope.order(indexable_order)
    scope = scope.limit(indexable_limit) if indexable_limit
    scope
  end

  # Apply search filtering to the scope
  def apply_search(scope)
    return scope if indexable_search_columns.empty?

    query = "%#{params[:search]}%"
    conditions = indexable_search_columns.map { |col| "#{col} ILIKE ?" }
    scope.where(conditions.join(' OR '), *([query] * indexable_search_columns.length))
  end

  # Find a single resource scoped to current website
  def find_scoped_resource
    require_website_context!
    indexable_model_class.where(website_id: current_website.id).find(params[:id])
  end

  # Set the collection instance variable (e.g., @contacts for Pwb::Contact)
  def set_collection_variable(collection)
    instance_variable_set("@#{collection_name}", collection)
  end

  # Set the resource instance variable (e.g., @contact for Pwb::Contact)
  def set_resource_variable(resource)
    instance_variable_set("@#{resource_name}", resource)
  end

  # Derive collection name from model (e.g., Pwb::Contact -> contacts)
  # Strips namespace to get simple name that matches view expectations
  def collection_name
    indexable_model_class.model_name.element.pluralize
  end

  # Derive resource name from model (e.g., Pwb::Contact -> contact)
  # Strips namespace to get simple name that matches view expectations
  def resource_name
    indexable_model_class.model_name.element
  end
end
