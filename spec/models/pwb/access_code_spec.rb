# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_access_codes
# Database name: primary
#
#  id         :uuid             not null, primary key
#  active     :boolean          default(TRUE), not null
#  code       :string           not null
#  expires_at :datetime
#  max_uses   :integer
#  uses_count :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_access_codes_on_website_id           (website_id)
#  index_pwb_access_codes_on_website_id_and_code  (website_id,code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

RSpec.describe Pwb::AccessCode, type: :model do
  let!(:website) { create(:pwb_website) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      code = build(:pwb_access_code, website: website)
      expect(code).to be_valid
    end

    it 'requires code' do
      code = build(:pwb_access_code, website: website, code: nil)
      expect(code).not_to be_valid
    end

    it 'enforces unique code per website' do
      create(:pwb_access_code, website: website, code: 'LONDON2026')
      duplicate = build(:pwb_access_code, website: website, code: 'LONDON2026')
      expect(duplicate).not_to be_valid
    end

    it 'allows same code on different websites' do
      other = create(:pwb_website)
      create(:pwb_access_code, website: website, code: 'SHARED')
      code = build(:pwb_access_code, website: other, code: 'SHARED')
      expect(code).to be_valid
    end
  end

  describe 'scopes' do
    it '.valid returns active, not expired, not exhausted codes' do
      valid = create(:pwb_access_code, website: website, active: true)
      create(:pwb_access_code, :expired, website: website)
      create(:pwb_access_code, :exhausted, website: website)
      create(:pwb_access_code, :inactive, website: website)

      expect(described_class.valid).to contain_exactly(valid)
    end

    it '.not_expired includes codes with nil expires_at' do
      no_expiry = create(:pwb_access_code, website: website, expires_at: nil)
      future = create(:pwb_access_code, website: website, expires_at: 1.day.from_now)
      create(:pwb_access_code, :expired, website: website)

      expect(described_class.not_expired).to contain_exactly(no_expiry, future)
    end

    it '.not_exhausted includes codes with nil max_uses' do
      unlimited = create(:pwb_access_code, website: website, max_uses: nil, uses_count: 999)
      has_uses = create(:pwb_access_code, website: website, max_uses: 10, uses_count: 5)
      create(:pwb_access_code, :exhausted, website: website)

      expect(described_class.not_exhausted).to contain_exactly(unlimited, has_uses)
    end
  end

  describe '#valid_code?' do
    it 'returns true for active, non-expired, non-exhausted code' do
      code = create(:pwb_access_code, website: website)
      expect(code.valid_code?).to be true
    end

    it 'returns false for expired code' do
      code = create(:pwb_access_code, :expired, website: website)
      expect(code.valid_code?).to be false
    end

    it 'returns false for exhausted code' do
      code = create(:pwb_access_code, :exhausted, website: website)
      expect(code.valid_code?).to be false
    end

    it 'returns false for inactive code' do
      code = create(:pwb_access_code, :inactive, website: website)
      expect(code.valid_code?).to be false
    end
  end

  describe '#redeem!' do
    it 'increments uses_count' do
      code = create(:pwb_access_code, website: website, uses_count: 0)
      expect { code.redeem! }.to change { code.reload.uses_count }.from(0).to(1)
    end
  end
end
