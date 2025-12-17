# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe FieldKey, type: :model do
    let(:website_a) { create(:pwb_website, subdomain: 'alpha') }
    let(:website_b) { create(:pwb_website, subdomain: 'beta') }

    describe 'validations' do
      it 'is valid with required attributes' do
        field_key = FieldKey.new(
          global_key: 'types.apartment',
          tag: 'property-types',
          website: website_a
        )
        expect(field_key).to be_valid
      end

      it 'requires global_key' do
        field_key = FieldKey.new(tag: 'property-types', website: website_a)
        expect(field_key).not_to be_valid
        expect(field_key.errors[:global_key]).to include("can't be blank")
      end

      it 'requires tag' do
        field_key = FieldKey.new(global_key: 'types.test', website: website_a)
        expect(field_key).not_to be_valid
        expect(field_key.errors[:tag]).to include("can't be blank")
      end

      describe 'uniqueness scoped by website' do
        before do
          FieldKey.create!(
            global_key: 'types.apartment',
            tag: 'property-types',
            website: website_a
          )
        end

        it 'allows same global_key in different websites' do
          field_key = FieldKey.new(
            global_key: 'types.apartment',
            tag: 'property-types',
            website: website_b
          )
          expect(field_key).to be_valid
        end

        it 'prevents duplicate global_key within same website' do
          field_key = FieldKey.new(
            global_key: 'types.apartment',
            tag: 'property-types',
            website: website_a
          )
          expect(field_key).not_to be_valid
          expect(field_key.errors[:global_key]).to include('has already been taken')
        end
      end
    end

    describe 'associations' do
      it 'belongs to website' do
        field_key = FieldKey.new(website: website_a)
        expect(field_key.website).to eq(website_a)
      end

      it 'allows nil website' do
        field_key = FieldKey.new(
          global_key: 'types.global',
          tag: 'property-types',
          website: nil
        )
        expect(field_key).to be_valid
      end
    end

    describe 'scopes' do
      before do
        @visible_key = FieldKey.create!(
          global_key: 'types.visible',
          tag: 'property-types',
          visible: true,
          website: website_a
        )
        @hidden_key = FieldKey.create!(
          global_key: 'types.hidden',
          tag: 'property-types',
          visible: false,
          website: website_a
        )
        @feature_key = FieldKey.create!(
          global_key: 'features.pool',
          tag: 'property-features',
          visible: true,
          website: website_a
        )
      end

      describe '.visible' do
        it 'returns only visible field keys' do
          expect(FieldKey.visible).to include(@visible_key)
          expect(FieldKey.visible).not_to include(@hidden_key)
        end
      end

      describe '.by_tag' do
        it 'returns field keys matching tag' do
          result = FieldKey.by_tag('property-types')
          expect(result).to include(@visible_key, @hidden_key)
          expect(result).not_to include(@feature_key)
        end
      end

      describe '.ordered' do
        before do
          @key1 = FieldKey.create!(
            global_key: 'types.z_last',
            tag: 'property-types',
            sort_order: 10,
            website: website_a
          )
          @key2 = FieldKey.create!(
            global_key: 'types.a_first',
            tag: 'property-types',
            sort_order: 1,
            website: website_a
          )
        end

        it 'orders by sort_order then created_at' do
          ordered = FieldKey.by_tag('property-types').ordered
          sort_orders = ordered.pluck(:sort_order).compact
          # Should be in ascending sort_order
          expect(sort_orders).to eq(sort_orders.sort)
        end
      end
    end

    describe '.get_options_by_tag' do
      before do
        @type1 = FieldKey.create!(
          global_key: 'types.apartment',
          tag: 'property-types',
          visible: true,
          sort_order: 2,
          website: website_a
        )
        @type2 = FieldKey.create!(
          global_key: 'types.villa',
          tag: 'property-types',
          visible: true,
          sort_order: 1,
          website: website_a
        )
        @hidden_type = FieldKey.create!(
          global_key: 'types.hidden',
          tag: 'property-types',
          visible: false,
          website: website_a
        )
        @feature = FieldKey.create!(
          global_key: 'features.pool',
          tag: 'property-features',
          visible: true,
          website: website_a
        )
      end

      it 'returns options for matching tag' do
        options = FieldKey.get_options_by_tag('property-types')
        values = options.map(&:value)

        expect(values).to include('types.apartment', 'types.villa')
        expect(values).not_to include('features.pool')
      end

      it 'excludes hidden field keys' do
        options = FieldKey.get_options_by_tag('property-types')
        values = options.map(&:value)

        expect(values).not_to include('types.hidden')
      end

      it 'respects sort_order' do
        options = FieldKey.get_options_by_tag('property-types')
        values = options.map(&:value)

        # villa (sort_order: 1) should come before apartment (sort_order: 2)
        expect(values.index('types.villa')).to be < values.index('types.apartment')
      end

      it 'returns OpenStruct with value, label, and sort_order' do
        options = FieldKey.get_options_by_tag('property-types')

        expect(options.first).to respond_to(:value)
        expect(options.first).to respond_to(:label)
        expect(options.first).to respond_to(:sort_order)
      end

      it 'uses global_key as fallback label if translation missing' do
        options = FieldKey.get_options_by_tag('property-types')
        villa_option = options.find { |o| o.value == 'types.villa' }

        # Without I18n translation, should fall back to global_key
        expect(villa_option.label).to eq('types.villa')
      end

      it 'returns empty array for unknown tag' do
        options = FieldKey.get_options_by_tag('nonexistent-tag')
        expect(options).to eq([])
      end
    end

    describe 'table configuration' do
      it 'uses pwb_field_keys table' do
        expect(FieldKey.table_name).to eq('pwb_field_keys')
      end

      it 'uses global_key as primary key' do
        expect(FieldKey.primary_key).to eq('global_key')
      end
    end

    describe 'Mobility translations' do
      let(:field_key) do
        FieldKey.create!(
          global_key: 'types.apartment',
          tag: 'property-types',
          website: website_a
        )
      end

      describe '#label with Mobility' do
        it 'stores and retrieves translations per locale' do
          Mobility.with_locale(:en) { field_key.label = 'Apartment' }
          Mobility.with_locale(:es) { field_key.label = 'Apartamento' }
          field_key.save!

          expect(Mobility.with_locale(:en) { field_key.label }).to eq('Apartment')
          expect(Mobility.with_locale(:es) { field_key.label }).to eq('Apartamento')
        end

        it 'falls back to other locales when translation missing' do
          Mobility.with_locale(:en) { field_key.label = 'Apartment' }
          field_key.save!

          # French was never set - Mobility falls back to English
          expect(Mobility.with_locale(:fr) { field_key.label }).to eq('Apartment')
        end

        it 'persists translations to database' do
          Mobility.with_locale(:en) { field_key.label = 'Apartment' }
          Mobility.with_locale(:de) { field_key.label = 'Wohnung' }
          field_key.save!

          # Reload from database
          reloaded = FieldKey.find('types.apartment')
          expect(Mobility.with_locale(:en) { reloaded.label }).to eq('Apartment')
          expect(Mobility.with_locale(:de) { reloaded.label }).to eq('Wohnung')
        end
      end

      describe '#display_label' do
        it 'returns the Mobility label when present' do
          Mobility.with_locale(:en) { field_key.label = 'Apartment' }
          field_key.save!

          I18n.with_locale(:en) do
            expect(field_key.display_label).to eq('Apartment')
          end
        end

        it 'falls back to global_key when label is blank' do
          # No label set
          expect(field_key.display_label).to eq('types.apartment')
        end

        it 'returns global_key when label is empty string' do
          Mobility.with_locale(:en) { field_key.label = '' }
          field_key.save!

          I18n.with_locale(:en) do
            expect(field_key.display_label).to eq('types.apartment')
          end
        end
      end

      describe 'translations isolation per website' do
        it 'stores different translations for different global_keys per website' do
          # Use different global_keys since FieldKey uses composite uniqueness
          field_key_a = FieldKey.create!(
            global_key: 'types.apartment_a',
            tag: 'property-types',
            website: website_a
          )
          Mobility.with_locale(:en) { field_key_a.label = 'Website A Apartment' }
          field_key_a.save!

          field_key_b = FieldKey.create!(
            global_key: 'types.apartment_b',
            tag: 'property-types',
            website: website_b
          )
          Mobility.with_locale(:en) { field_key_b.label = 'Website B Apartment' }
          field_key_b.save!

          field_key_a.reload
          field_key_b.reload

          expect(Mobility.with_locale(:en) { field_key_a.label }).to eq('Website A Apartment')
          expect(Mobility.with_locale(:en) { field_key_b.label }).to eq('Website B Apartment')
        end

        it 'allows same global_key with different translations in different websites' do
          # Same global_key can exist in different websites with different translations
          key_website_a = FieldKey.create!(
            global_key: 'types.shared',
            tag: 'property-types',
            website: website_a
          )
          Mobility.with_locale(:en) { key_website_a.label = 'Shared A' }
          key_website_a.save!

          key_website_b = FieldKey.create!(
            global_key: 'types.shared',
            tag: 'property-types',
            website: website_b
          )
          Mobility.with_locale(:en) { key_website_b.label = 'Shared B' }
          key_website_b.save!

          # Verify each record has its own translation
          expect(key_website_a.translations).to eq({ 'en' => { 'label' => 'Shared A' } })
          expect(key_website_b.translations).to eq({ 'en' => { 'label' => 'Shared B' } })
        end
      end
    end
  end
end

module PwbTenant
  RSpec.describe FieldKey, type: :model do
    let(:website_a) { create(:pwb_website, subdomain: 'alpha') }
    let(:website_b) { create(:pwb_website, subdomain: 'beta') }

    after do
      ActsAsTenant.current_tenant = nil
    end

    describe 'tenant scoping' do
      before do
        # Create field keys for both websites using Pwb:: (unscoped)
        # Use different global_keys to distinguish them
        @key_a = Pwb::FieldKey.create!(
          global_key: 'types.apartment_a',
          tag: 'property-types',
          website: website_a
        )
        @key_b = Pwb::FieldKey.create!(
          global_key: 'types.apartment_b',
          tag: 'property-types',
          website: website_b
        )
      end

      it 'raises error when no tenant is set' do
        expect {
          PwbTenant::FieldKey.count
        }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end

      it 'scopes queries to current tenant' do
        ActsAsTenant.current_tenant = website_a

        keys = PwbTenant::FieldKey.pluck(:global_key)
        expect(keys).to include('types.apartment_a')
        expect(keys).not_to include('types.apartment_b')
      end

      it 'allows same global_key in different tenants' do
        # Create same key in both websites
        Pwb::FieldKey.create!(global_key: 'types.shared', tag: 'property-types', website: website_a)
        Pwb::FieldKey.create!(global_key: 'types.shared', tag: 'property-types', website: website_b)

        ActsAsTenant.current_tenant = website_a
        expect(PwbTenant::FieldKey.find_by(global_key: 'types.shared')).to be_present

        ActsAsTenant.current_tenant = website_b
        expect(PwbTenant::FieldKey.find_by(global_key: 'types.shared')).to be_present
      end
    end

    describe '.get_options_by_tag with tenant' do
      before do
        Pwb::FieldKey.create!(
          global_key: 'types.apartment',
          tag: 'property-types',
          visible: true,
          website: website_a
        )
        Pwb::FieldKey.create!(
          global_key: 'types.villa',
          tag: 'property-types',
          visible: true,
          website: website_b
        )
      end

      it 'returns only current tenant options' do
        ActsAsTenant.current_tenant = website_a

        options = PwbTenant::FieldKey.get_options_by_tag('property-types')
        values = options.map(&:value)

        expect(values).to include('types.apartment')
        expect(values).not_to include('types.villa')
      end
    end

    describe 'creating field keys' do
      it 'automatically assigns website from current tenant' do
        ActsAsTenant.current_tenant = website_a

        field_key = PwbTenant::FieldKey.create!(
          global_key: 'types.new_type',
          tag: 'property-types'
        )

        # Reload to get fresh data from DB
        field_key.reload
        expect(field_key.pwb_website_id).to eq(website_a.id)
      end
    end
  end
end
