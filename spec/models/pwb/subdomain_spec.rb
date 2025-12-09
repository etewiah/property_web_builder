require 'rails_helper'

module Pwb
  RSpec.describe Subdomain, type: :model do
    describe 'validations' do
      it 'has a valid factory' do
        subdomain = Subdomain.new(name: 'valid-subdomain-42')
        expect(subdomain).to be_valid
      end

      it 'requires a name' do
        subdomain = Subdomain.new(name: nil)
        expect(subdomain).not_to be_valid
        expect(subdomain.errors[:name]).to include("can't be blank")
      end

      it 'requires unique name' do
        Subdomain.create!(name: 'unique-name-42')
        duplicate = Subdomain.new(name: 'unique-name-42')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'validates name format - no uppercase' do
        subdomain = Subdomain.new(name: 'Invalid-Name')
        expect(subdomain).not_to be_valid
      end

      it 'validates name format - no leading hyphen' do
        subdomain = Subdomain.new(name: '-invalid-name')
        expect(subdomain).not_to be_valid
      end

      it 'validates name format - no trailing hyphen' do
        subdomain = Subdomain.new(name: 'invalid-name-')
        expect(subdomain).not_to be_valid
      end

      it 'validates minimum length' do
        subdomain = Subdomain.new(name: 'ab')
        expect(subdomain).not_to be_valid
        expect(subdomain.errors[:name]).to include('is too short (minimum is 5 characters)')
      end

      it 'validates maximum length' do
        subdomain = Subdomain.new(name: 'a' * 50)
        expect(subdomain).not_to be_valid
        expect(subdomain.errors[:name]).to include('is too long (maximum is 40 characters)')
      end

      it 'rejects reserved names' do
        subdomain = Subdomain.new(name: 'admin')
        expect(subdomain).not_to be_valid
        expect(subdomain.errors[:name]).to include('is reserved and cannot be used')
      end
    end

    describe 'state machine' do
      let(:subdomain) { Subdomain.create!(name: 'test-subdomain-99') }
      let(:website) { FactoryBot.create(:pwb_website) }

      it 'starts in available state' do
        expect(subdomain.aasm_state).to eq('available')
        expect(subdomain).to be_available
      end

      describe '#reserve!' do
        it 'transitions from available to reserved' do
          subdomain.reserve!('user@example.com')
          expect(subdomain).to be_reserved
          expect(subdomain.reserved_by_email).to eq('user@example.com')
          expect(subdomain.reserved_at).to be_present
          expect(subdomain.reserved_until).to be_present
        end

        it 'sets reserved_until to specified duration' do
          subdomain.reserve!('user@example.com', 10.minutes)
          expect(subdomain.reserved_until).to be_within(1.second).of(Time.current + 10.minutes)
        end

        it 'cannot reserve if already reserved' do
          subdomain.reserve!('user@example.com')
          expect(subdomain).not_to be_may_reserve
        end
      end

      describe '#allocate!' do
        it 'transitions from reserved to allocated' do
          subdomain.reserve!('user@example.com')
          subdomain.allocate!(website)
          expect(subdomain).to be_allocated
          expect(subdomain.website).to eq(website)
          expect(subdomain.reserved_by_email).to be_nil
        end

        it 'can allocate directly from available' do
          subdomain.allocate!(website)
          expect(subdomain).to be_allocated
          expect(subdomain.website).to eq(website)
        end
      end

      describe '#release!' do
        it 'transitions from allocated to released' do
          subdomain.allocate!(website)
          subdomain.release!
          expect(subdomain).to be_released
          expect(subdomain.website).to be_nil
        end

        it 'transitions from reserved to released' do
          subdomain.reserve!('user@example.com')
          subdomain.release!
          expect(subdomain).to be_released
        end
      end

      describe '#make_available!' do
        it 'transitions from released to available' do
          subdomain.allocate!(website)
          subdomain.release!
          subdomain.make_available!
          expect(subdomain).to be_available
        end
      end
    end

    describe '.reserve_for_email' do
      it 'reserves an available subdomain for the email' do
        5.times { |i| Subdomain.create!(name: "reserve-email-#{i}-#{rand(1000..9999)}") }
        subdomain = Subdomain.reserve_for_email('reserve-user@example.com')
        expect(subdomain).to be_reserved
        expect(subdomain.reserved_by_email).to eq('reserve-user@example.com')
      end

      it 'returns nil if no subdomains available' do
        # Stub available scope to return empty relation
        allow(Subdomain).to receive(:available).and_return(Subdomain.none)
        # Use a unique email to avoid finding existing reservations
        subdomain = Subdomain.reserve_for_email("noavail-#{rand(1000..9999)}@example.com")
        expect(subdomain).to be_nil
      end

      it 'returns existing reservation for same email' do
        5.times { |i| Subdomain.create!(name: "existing-res-#{i}-#{rand(1000..9999)}") }
        unique_email = "existing-res-#{rand(1000..9999)}@example.com"
        first = Subdomain.reserve_for_email(unique_email)
        second = Subdomain.reserve_for_email(unique_email)
        expect(second.id).to eq(first.id)
      end
    end

    describe 'scopes' do
      before do
        @available = Subdomain.create!(name: 'scope-available-1', aasm_state: 'available')
        @reserved = Subdomain.create!(name: 'scope-reserved-1', aasm_state: 'reserved', reserved_until: 1.hour.from_now)
        @expired = Subdomain.create!(name: 'scope-expired-1', aasm_state: 'reserved', reserved_until: 1.hour.ago)
        @allocated = Subdomain.create!(name: 'scope-allocated-1', aasm_state: 'allocated')
      end

      it '.available returns only available subdomains' do
        expect(Subdomain.available).to include(@available)
        expect(Subdomain.available).not_to include(@reserved, @allocated)
      end

      it '.reserved returns only reserved subdomains' do
        expect(Subdomain.reserved).to include(@reserved, @expired)
        expect(Subdomain.reserved).not_to include(@available, @allocated)
      end

      it '.expired_reservations returns only expired reserved subdomains' do
        expect(Subdomain.expired_reservations).to include(@expired)
        expect(Subdomain.expired_reservations).not_to include(@reserved, @available)
      end
    end
  end
end
