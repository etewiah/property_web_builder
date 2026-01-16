# frozen_string_literal: true

# Preview for pagination component
# @label Pagination
class PaginationPreview < Lookbook::Preview
  # First page pagination
  # @label First Page
  def first_page
    render_with_template
  end

  # Middle page pagination
  # @label Middle Page
  def middle_page
    render_with_template
  end

  # Last page pagination
  # @label Last Page
  def last_page
    render_with_template
  end
end
