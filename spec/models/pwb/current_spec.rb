# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Current, type: :model do
  let!(:website) { FactoryBot.create(:pwb_website) }

  describe 'thread safety' do
    it 'isolates website between threads' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'thread1')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'thread2')

      thread1_result = nil
      thread2_result = nil

      t1 = Thread.new do
        Pwb::Current.website = website1
        sleep 0.01 # Give other thread time to set its value
        thread1_result = Pwb::Current.website
      end

      t2 = Thread.new do
        Pwb::Current.website = website2
        sleep 0.01 # Give other thread time to set its value
        thread2_result = Pwb::Current.website
      end

      t1.join
      t2.join

      # Each thread should maintain its own isolated value
      expect(thread1_result).to eq(website1)
      expect(thread2_result).to eq(website2)
    end

    it 'resets between requests' do
      Pwb::Current.website = website
      expect(Pwb::Current.website).to eq(website)

      # Simulate new request (ActiveSupport::CurrentAttributes auto-resets between requests)
      Pwb::Current.reset
      expect(Pwb::Current.website).to be_nil
    end
  end

  describe 'attribute access' do
    it 'allows setting and getting website' do
      Pwb::Current.website = website
      expect(Pwb::Current.website).to eq(website)
    end

    it 'starts as nil in new context' do
      Pwb::Current.reset
      expect(Pwb::Current.website).to be_nil
    end

    it 'can be set to nil explicitly' do
      Pwb::Current.website = website
      Pwb::Current.website = nil
      expect(Pwb::Current.website).to be_nil
    end
  end

  describe 'ActiveSupport::CurrentAttributes behavior' do
    it 'is isolated per request/thread' do
      expect(Pwb::Current).to be_a(Class)
      expect(Pwb::Current.superclass).to eq(ActiveSupport::CurrentAttributes)
    end

    it 'provides automatic reset after request' do
      # Set website
      Pwb::Current.website = website
      
      # Simulate request completion (Rails does this automatically)
      Pwb::Current.reset
      
      # Should be nil after reset
      expect(Pwb::Current.website).to be_nil
    end
  end
end
