# frozen_string_literal: true

# Preview for pagination component
# @label Pagination
class PaginationPreview < Lookbook::Preview
  # First page pagination
  # @label First Page
  def first_page
    render inline: <<~ERB
      <div style="padding: 2rem; background: #f5f5f5;">
        <h3 style="margin-bottom: 1rem;">Pagination - Page 1 of 10</h3>
        <%= render partial: "shared/pagination", locals: { 
          current_page: 1, 
          total_pages: 10,
          base_path: "/properties" 
        } %>
      </div>
    ERB
  end

  # Middle page pagination
  # @label Middle Page
  def middle_page
    render inline: <<~ERB
      <div style="padding: 2rem; background: #f5f5f5;">
        <h3 style="margin-bottom: 1rem;">Pagination - Page 5 of 10</h3>
        <%= render partial: "shared/pagination", locals: { 
          current_page: 5, 
          total_pages: 10,
          base_path: "/properties" 
        } %>
      </div>
    ERB
  end

  # Last page pagination
  # @label Last Page
  def last_page
    render inline: <<~ERB
      <div style="padding: 2rem; background: #f5f5f5;">
        <h3 style="margin-bottom: 1rem;">Pagination - Page 10 of 10</h3>
        <%= render partial: "shared/pagination", locals: { 
          current_page: 10, 
          total_pages: 10,
          base_path: "/properties" 
        } %>
      </div>
    ERB
  end
end
