# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings tab forms have hidden tab fields', type: :view do
  # This spec ensures that each settings tab form includes the required hidden
  # 'tab' field. Without this field, the SettingsController won't know which
  # update method to call and will default to 'general', causing saves to fail
  # silently.
  #
  # Background: The SEO tab was missing this field which caused "Save SEO Settings"
  # to just redirect without saving. This spec prevents similar regressions.

  let(:website) { create(:pwb_website, subdomain: 'hidden-tab-test') }

  # Tabs that POST to site_admin_website_settings_path and require the hidden 'tab' field
  # Note: 'navigation' tab uses a different URL (site_admin_website_update_links_path)
  # so it doesn't need the hidden tab field
  TABS_REQUIRING_HIDDEN_FIELD = %w[general appearance seo social notifications home].freeze

  before do
    # Set up required instance variables for views
    assign(:website, website)
    assign(:themes, [])
    assign(:style_variables, {})
    assign(:social_links, [])
    assign(:social_media, {})
    assign(:home_page, nil)
    assign(:carousel_contents, [])
  end

  describe 'verifying hidden tab field presence' do
    TABS_REQUIRING_HIDDEN_FIELD.each do |tab_name|
      context "#{tab_name} tab" do
        it "includes hidden field with name='tab' and value='#{tab_name}'" do
          # Read the partial file directly and check for the hidden field
          partial_path = Rails.root.join(
            'app/views/site_admin/website/settings',
            "_#{tab_name}_tab.html.erb"
          )

          expect(File.exist?(partial_path)).to be(true),
            "Expected partial file to exist at #{partial_path}"

          content = File.read(partial_path)

          # Check for either format of hidden field:
          # 1. Raw HTML: <input type="hidden" name="tab" value="#{tab_name}">
          # 2. Rails helper: hidden_field_tag :tab, '#{tab_name}'
          has_raw_hidden_field = content.match?(
            /<input\s+type="hidden"\s+name="tab"\s+value="#{tab_name}"/
          )
          has_rails_helper = content.match?(
            /hidden_field_tag\s+:tab,\s+['"]#{tab_name}['"]/
          )

          expect(has_raw_hidden_field || has_rails_helper).to be(true),
            "Expected #{tab_name}_tab.html.erb to contain a hidden 'tab' field with value '#{tab_name}'.\n" \
            "Add one of:\n  " \
            "<input type=\"hidden\" name=\"tab\" value=\"#{tab_name}\">\n  " \
            "OR\n  " \
            "<%= hidden_field_tag :tab, '#{tab_name}' %>\n\n" \
            "Without this field, the SettingsController won't know to call update_#{tab_name}_settings " \
            "and will default to update_general_settings, causing the save to silently fail."
        end
      end
    end
  end

  describe 'navigation tab uses different URL' do
    it 'posts to update_links_path instead of settings_path' do
      partial_path = Rails.root.join(
        'app/views/site_admin/website/settings',
        '_navigation_tab.html.erb'
      )

      expect(File.exist?(partial_path)).to be(true)

      content = File.read(partial_path)

      # Navigation tab should use update_links_path, not settings_path
      expect(content).to include('site_admin_website_update_links_path'),
        "Expected navigation_tab.html.erb to post to site_admin_website_update_links_path"

      # And should NOT have a hidden tab field (since it uses a different endpoint)
      has_hidden_tab = content.match?(/<input\s+type="hidden"\s+name="tab"/)
      expect(has_hidden_tab).to be(false),
        "navigation_tab.html.erb should NOT have a hidden 'tab' field since it uses a different endpoint"
    end
  end
end
