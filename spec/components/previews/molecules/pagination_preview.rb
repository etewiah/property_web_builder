# frozen_string_literal: true

# Preview for pagination component
# @label Pagination
class Molecules::PaginationPreview < Lookbook::Preview
  include PreviewHelper

  # Default pagination
  # @label Default
  def default
    render partial: "shared/pagination", locals: {
      current_page: 1,
      total_pages: 10,
      base_path: "/properties"
    }
  end

  # Middle page pagination
  # @label Middle Page
  # @notes
  #   Shows pagination when user is in the middle of results,
  #   with both previous and next navigation available.
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

  # Interactive playground
  # @label Playground
  # @param current_page number
  # @param total_pages number
  # @param palette select { choices: [default, ocean, sunset, forest] }
  def playground(current_page: 3, total_pages: 15, palette: :default)
    with_palette(palette) do
      render partial: "shared/pagination", locals: {
        current_page: current_page.to_i,
        total_pages: total_pages.to_i,
        base_path: "/properties"
      }
    end
  end
end
