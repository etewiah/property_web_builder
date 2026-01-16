# frozen_string_literal: true

# Preview for GDPR consent banner component
# @label Consent Banner
class Molecules::ConsentBannerPreview < Lookbook::Preview
  include PreviewHelper

  # Default consent banner
  # @label Default
  # @notes
  #   The cookie consent banner that appears at the bottom of the page.
  #   Allows users to accept or customize their cookie preferences.
  def default
    render partial: "shared/consent_banner"
  end

  # Playground with theme options
  # @label Playground
  # @param palette select { choices: [default, ocean, sunset, forest] }
  def playground(palette: :default)
    with_palette(palette) do
      render partial: "shared/consent_banner"
    end
  end
end
