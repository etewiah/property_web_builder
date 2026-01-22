# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'pwb:content:reprocess_responsive', type: :task do
  before(:all) do
    Rake.application.rake_require 'tasks/content_responsive'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['pwb:content:reprocess_responsive'] }

  before do
    task.reenable
  end

  # Create a content record that needs updating
  let!(:hero_content) do
    Pwb::Content.create!(
      key: 'heroes/hero_centered',
      page_part_key: 'heroes/hero_centered',
      raw_en: '<div class="hero-section"><img src="https://example.com/image.jpg" /></div>'
    )
  end

  let!(:standard_content) do
    Pwb::Content.create!(
      key: 'about_us_content',
      page_part_key: 'about_us_content',
      raw_en: '<div class="content"><img src="https://example.com/image.jpg" /></div>'
    )
  end

  it 'updates hero content with hero sizes' do
    # Verify initial state
    expect(hero_content.raw_en).not_to include('sizes=')

    # Capture stdout to avoid cluttering test output
    expect { task.invoke }.to output(/Processed: 2/).to_stdout

    hero_content.reload
    
    # Should have sizes attribute for hero
    # exact string depends on Pwb::ResponsiveVariants::SIZE_PRESETS[:hero]
    expect(hero_content.raw_en).to include('sizes="(min-width: 1280px) 1280px, 100vw"')
    
    # Should be upgraded to picture tag (mocked helper behavior)
    # Note: make_media_responsive uses trusted_webp_source? which defaults to false for example.com
    # UNLESS we stub it or use a trusted domain.
    # But wait, make_media_responsive ONLY upgrades to <picture> if trusted.
    # However, it ALWAYS adds `sizes` to the <img> tag if it's not there.
  end

  context 'with trusted image source' do
    let!(:trusted_content) do
      Pwb::Content.create!(
        key: 'trusted_hero',
        page_part_key: 'trusted_hero',
        raw_en: '<div class="hero-section"><img src="https://seed-assets.propertywebbuilder.com/image.jpg" /></div>'
      )
    end

    it 'upgrades trusted images to picture tags' do
      expect { task.invoke }.to output.to_stdout

      trusted_content.reload
      expect(trusted_content.raw_en).to include('<picture>')
      expect(trusted_content.raw_en).to include('type="image/webp"')
    end
  end
end
