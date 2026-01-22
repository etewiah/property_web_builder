# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'zoho rake tasks', type: :task do
  before(:all) do
    Rake.application.rake_require 'tasks/zoho'
    Rake::Task.define_task(:environment)
  end

  before do
    # Reset singleton between tests
    Pwb::Zoho::Client.reset!
  end

  describe 'zoho:status' do
    let(:task) { Rake::Task['zoho:status'] }

    before do
      task.reenable
    end

    context 'when Zoho is not configured' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ZOHO_CLIENT_ID').and_return(nil)
        allow(ENV).to receive(:[]).with('ZOHO_CLIENT_SECRET').and_return(nil)
        allow(ENV).to receive(:[]).with('ZOHO_REFRESH_TOKEN').and_return(nil)
        allow(Rails.application.credentials).to receive(:zoho).and_return(nil)
      end

      it 'displays NOT CONFIGURED status' do
        expect { task.invoke }.to output(/Status: NOT CONFIGURED/).to_stdout
      end

      it 'shows missing configuration instructions' do
        expect { task.invoke }.to output(/ZOHO_CLIENT_ID/).to_stdout
      end
    end

    context 'error class loading' do
      it 'loads AuthenticationError without NameError' do
        expect { Pwb::Zoho::AuthenticationError }.not_to raise_error
      end

      it 'loads Error base class without NameError' do
        expect { Pwb::Zoho::Error }.not_to raise_error
      end

      it 'loads all error classes' do
        expect { Pwb::Zoho::ConfigurationError }.not_to raise_error
        expect { Pwb::Zoho::ValidationError }.not_to raise_error
        expect { Pwb::Zoho::NotFoundError }.not_to raise_error
        expect { Pwb::Zoho::ApiError }.not_to raise_error
        expect { Pwb::Zoho::TimeoutError }.not_to raise_error
        expect { Pwb::Zoho::ConnectionError }.not_to raise_error
        expect { Pwb::Zoho::RateLimitError }.not_to raise_error
      end
    end
  end

  describe 'zoho:stats' do
    let(:task) { Rake::Task['zoho:stats'] }

    before do
      task.reenable
    end

    it 'displays statistics header' do
      expect { task.invoke }.to output(/Zoho Sync Statistics/).to_stdout
    end

    it 'shows total users count' do
      create(:pwb_user)
      expect { task.invoke }.to output(/Total:.*1/m).to_stdout
    end

    it 'shows synced users count' do
      create(:pwb_user, metadata: { zoho_lead_id: 'lead123' })
      expect { task.invoke }.to output(/Synced:.*1/m).to_stdout
    end

    it 'shows converted users count' do
      create(:pwb_user, metadata: { zoho_contact_id: 'contact123' })
      expect { task.invoke }.to output(/Converted:.*1/m).to_stdout
    end
  end
end
