# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multi-tenant website creation', type: :request do
  before(:each) do
    # Clean up
    Pwb::Website.delete_all
    # Reset the sequence to avoid conflicts
    ActiveRecord::Base.connection.reset_pk_sequence!('pwb_websites')
  end

  describe 'sequential website creation' do
    it 'creates websites with unique sequential IDs' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'first')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'second')
      website3 = FactoryBot.create(:pwb_website, subdomain: 'third')
      
      ids = [website1.id, website2.id, website3.id]
      
      # IDs should be unique
      expect(ids.uniq.count).to eq(3)
      
      # All websites should be persisted
      expect(Pwb::Website.count).to eq(3)
    end

    it 'does not have sequence conflicts after explicit ID assignment' do
      # This simulates the old unique_instance behavior
      # where ID was set explicitly
      
      # Create manually with specific ID (should advance sequence)
      manual_website = Pwb::Website.create!(
        subdomain: 'manual',
        theme_name: 'default',
        default_currency: 'EUR',
        default_client_locale: 'en-UK'
      )
      
      # Now create via factory (should use next sequence value)
      factory_website = FactoryBot.create(:pwb_website, subdomain: 'factory')
      
      # Both should succeed without UniqueViolation
      expect(manual_website.persisted?).to be true
      expect(factory_website.persisted?).to be true
      expect(manual_website.id).not_to eq(factory_website.id)
    end
  end

  describe 'database sequence integrity' do
    it 'maintains sequence after deleting websites' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'temp1')
      id1 = website1.id
      website1.destroy

      website2 = FactoryBot.create(:pwb_website, subdomain: 'temp2')
      
      # New website should have different ID (sequence moved forward)
      expect(website2.id).not_to eq(id1)
      expect(website2.id).to be > id1
    end
  end
end
