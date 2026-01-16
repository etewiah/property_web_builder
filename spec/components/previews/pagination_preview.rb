# frozen_string_literal: true

# Preview for pagination component
# @label Pagination
class PaginationPreview < Lookbook::Preview
  # First page pagination
  # @label First Page
  def first_page
    render partial: "shared/pagination", locals: {
      current_page: 1,
      total_pages: 10,
      base_path: "/properties"
    }
  end

  # Middle page pagination
  # @label Middle Page
  def middle_page
    render partial: "shared/pagination", locals: {
      current_page: 5,
      total_pages: 10,
      base_path: "/properties"
    }
  end

  # Last page pagination
  # @label Last Page
  def last_page
    render partial: "shared/pagination", locals: {
      current_page: 10,
      total_pages: 10,
      base_path: "/properties"
    }
  end
end
