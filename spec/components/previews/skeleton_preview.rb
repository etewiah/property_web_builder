# frozen_string_literal: true

# Preview for skeleton loader components
# @label Skeleton Loader
class SkeletonPreview < Lookbook::Preview
  # Default skeleton loader
  # @label Default
  def default
    render inline: <<~ERB
      <div style="padding: 2rem; background: #f5f5f5;">
        <h3 style="margin-bottom: 1rem;">Skeleton Loader Preview</h3>
        <%= render partial: "shared/skeleton" %>
      </div>
    ERB
  end
end
