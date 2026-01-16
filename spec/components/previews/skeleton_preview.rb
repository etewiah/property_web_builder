# frozen_string_literal: true

# Preview for skeleton loader components
# @label Skeleton Loader
class SkeletonPreview < Lookbook::Preview
  # Default skeleton loader
  # @label Default
  def default
    render partial: "shared/skeleton"
  end
end
