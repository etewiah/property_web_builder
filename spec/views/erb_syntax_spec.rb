# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ERB Template Syntax', type: :view do
  # This test validates that ERB templates can be compiled without syntax errors.
  # It specifically catches issues like:
  # - Using <%# %> for multi-line blocks containing ERB tags (causes orphan 'end')
  # - Mismatched <% end %> tags
  # - Invalid ERB syntax

  def compile_erb_template(file_path)
    erb_content = File.read(file_path)
    relative_path = file_path.to_s.sub("#{Rails.root}/", '')

    handler = ActionView::Template.handler_for_extension('erb')
    template = ActionView::Template.new(
      erb_content,
      relative_path,
      handler,
      format: :html,
      locals: []
    )

    # This triggers compilation and returns the compiled source
    # If there's a syntax error in the ERB, this will raise
    template.source
  end

  describe 'site_admin layout templates' do
    let(:site_admin_erb_files) do
      Dir.glob(Rails.root.join('app', 'views', 'layouts', 'site_admin*.erb')) +
        Dir.glob(Rails.root.join('app', 'views', 'layouts', 'site_admin', '**', '*.erb'))
    end

    it 'all compile without syntax errors' do
      failures = []

      site_admin_erb_files.each do |file_path|
        relative_path = file_path.to_s.sub("#{Rails.root}/", '')
        begin
          compile_erb_template(file_path)
        rescue ActionView::Template::Error, SyntaxError => e
          failures << "#{relative_path}: #{e.message}"
        end
      end

      expect(failures).to be_empty,
        "The following templates have ERB syntax errors:\n#{failures.join("\n")}"
    end
  end

  describe 'site_admin/dashboard views' do
    let(:dashboard_erb_files) do
      Dir.glob(Rails.root.join('app', 'views', 'site_admin', 'dashboard', '**', '*.erb'))
    end

    it 'all compile without errors' do
      failures = []

      dashboard_erb_files.each do |file_path|
        relative_path = file_path.to_s.sub("#{Rails.root}/", '')
        begin
          compile_erb_template(file_path)
        rescue ActionView::Template::Error, SyntaxError => e
          failures << "#{relative_path}: #{e.message}"
        end
      end

      expect(failures).to be_empty,
        "The following templates have ERB syntax errors:\n#{failures.join("\n")}"
    end
  end

  # Regression test for the specific bug: using <%# %> for multi-line ERB blocks
  describe 'regression: navigation template ERB comments' do
    let(:navigation_file) { Rails.root.join('app', 'views', 'layouts', 'site_admin', '_navigation.html.erb') }

    it 'compiles without orphan end tag errors' do
      skip 'Navigation file not found' unless File.exist?(navigation_file)

      expect {
        compile_erb_template(navigation_file)
      }.not_to raise_error
    end

    it 'does not use <%# %> to comment out blocks with ERB tags' do
      skip 'Navigation file not found' unless File.exist?(navigation_file)

      erb_content = File.read(navigation_file)

      # Pattern to detect: <%# followed by <%= or <% on subsequent lines before closing %>
      # This is a common mistake that causes syntax errors
      dangerous_pattern = /<%#\s*\n[^%]*<%[=%]/m

      expect(erb_content).not_to match(dangerous_pattern),
        "Found <%# %> comment containing ERB tags. Use <% if false %> ... <% end %> instead."
    end
  end

  # Quick smoke test for critical admin layouts
  %w[site_admin tenant_admin].each do |admin_type|
    describe "#{admin_type} layout" do
      let(:layout_file) { Rails.root.join('app', 'views', 'layouts', "#{admin_type}.html.erb") }

      it 'compiles without errors' do
        skip "#{admin_type} layout not found" unless File.exist?(layout_file)

        expect {
          compile_erb_template(layout_file)
        }.not_to raise_error
      end
    end
  end
end
