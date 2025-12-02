require 'rails_helper'
require 'rake'

RSpec.describe 'pwb:db:update_page_parts' do
  before :all do
    Rake.application.rake_require 'tasks/pwb_update_seeds', [Rails.root.join('lib').to_s]
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['pwb:db:update_page_parts'] }

  # We need to re-enable the task after each run so it can be invoked again
  after(:each) do
    task.reenable
  end

  describe 'task execution' do
    let(:page_slug) { 'test_page' }
    let(:page_part_key) { 'test_key' }
    let(:mock_yaml) do
      [{
        'page_slug' => page_slug,
        'page_part_key' => page_part_key,
        'template' => '<p>New Template</p>',
        'editor_setup' => {}
      }]
    end
    
    # Create the necessary database records
    let!(:page) { Pwb::Page.create!(slug: page_slug) }
    let!(:page_part) { Pwb::PagePart.create!(page_slug: page_slug, page_part_key: page_part_key, template: '<p>Old</p>') }

    before do
      # Mock the directory iteration to avoid reading all actual seed files
      mock_dir = double('Pathname')
      mock_file = double('Pathname', extname: '.yml', basename: 'test.yml')
      
      allow(Rails.root).to receive(:join).and_call_original
      allow(Rails.root).to receive(:join).with('db', 'yml_seeds', 'page_parts').and_return(mock_dir)
      allow(mock_dir).to receive(:children).and_return([mock_file])
      
      allow(YAML).to receive(:load_file).and_return({})
      allow(YAML).to receive(:load_file).with(mock_file).and_return(mock_yaml)
      
      # Mock content translations to avoid errors or complex setup for this specific test
      # We assume no translation files exist for this test case to simplify
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(include('content_translations')).and_return(false)
    end

    it 'updates the page part template from the YAML file' do
      expect { task.invoke }.to change { page_part.reload.template }.from('<p>Old</p>').to('<p>New Template</p>')
    end

    it 'finds the correct container page' do
      expect(Pwb::Page).to receive(:find_by_slug).with(page_slug).at_least(:once).and_call_original
      task.invoke
    end
  end
end
