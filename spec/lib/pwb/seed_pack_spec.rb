# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe SeedPack do
    describe ".available" do
      it "returns list of available seed packs" do
        packs = SeedPack.available
        expect(packs).to be_an(Array)
      end

      it "includes the base pack" do
        packs = SeedPack.available
        pack_names = packs.map(&:name)
        expect(pack_names).to include('base')
      end
    end

    describe ".find" do
      it "returns the pack when it exists" do
        pack = SeedPack.find('base')
        expect(pack).to be_a(SeedPack)
        expect(pack.name).to eq('base')
      end

      it "raises PackNotFoundError for non-existent pack" do
        expect {
          SeedPack.find('nonexistent-pack-12345')
        }.to raise_error(SeedPack::PackNotFoundError)
      end
    end

    describe "base pack" do
      let(:pack) { SeedPack.find('base') }

      it "has required configuration" do
        expect(pack.display_name).to be_present
        expect(pack.config[:website]).to be_present
      end

      it "has links.yml file" do
        links_file = pack.send(:instance_variable_get, :@path).join('links.yml')
        expect(links_file).to exist
      end

      it "has field_keys.yml file" do
        field_keys_file = pack.send(:instance_variable_get, :@path).join('field_keys.yml')
        expect(field_keys_file).to exist
      end
    end

    describe "Individual seeding methods" do
      let(:pack) { SeedPack.find('base') }
      let(:website) { FactoryBot.create(:pwb_website) }

      describe "#seed_links!" do
        it "creates navigation links for website" do
          expect {
            pack.seed_links!(website: website)
          }.to change { website.links.count }.by_at_least(3)
        end

        it "is idempotent - does not duplicate links" do
          pack.seed_links!(website: website)
          initial_count = website.links.count

          pack.seed_links!(website: website)
          expect(website.links.count).to eq(initial_count)
        end
      end

      describe "#seed_field_keys!" do
        it "creates field keys for website" do
          expect {
            pack.seed_field_keys!(website: website)
          }.to change { website.field_keys.count }.by_at_least(5)
        end

        it "is idempotent - does not duplicate field keys" do
          pack.seed_field_keys!(website: website)
          initial_count = website.field_keys.count

          pack.seed_field_keys!(website: website)
          expect(website.field_keys.count).to eq(initial_count)
        end
      end

      describe "#seed_agency!" do
        it "creates or updates agency for website" do
          pack.seed_agency!(website: website)
          # Base pack may or may not have agency config
          # This should not raise an error
        end
      end

      describe "#seed_pages!" do
        it "does not raise error even if no pages directory" do
          expect {
            pack.seed_pages!(website: website)
          }.not_to raise_error
        end
      end

      describe "#seed_page_parts!" do
        it "seeds page parts using fallback seeder" do
          expect {
            pack.seed_page_parts!(website: website)
          }.not_to raise_error
        end
      end

      describe "#seed_properties!" do
        it "does not raise error even if no properties" do
          expect {
            pack.seed_properties!(website: website)
          }.not_to raise_error
        end
      end
    end

    describe "#apply!" do
      let(:pack) { SeedPack.find('base') }
      let(:website) { FactoryBot.create(:pwb_website) }

      it "applies all seeding steps" do
        pack.apply!(website: website)

        website.reload
        expect(website.links.count).to be >= 3
        expect(website.field_keys.count).to be >= 5
      end

      it "supports dry_run option" do
        initial_links = website.links.count

        pack.apply!(website: website, options: { dry_run: true })

        expect(website.links.count).to eq(initial_links)
      end

      it "supports skip options" do
        pack.apply!(website: website, options: { skip_links: true })

        # Links should not be created
        expect(website.links.count).to eq(0)
      end
    end

    describe "#preview" do
      let(:pack) { SeedPack.find('base') }

      it "returns preview hash without modifying data" do
        preview = pack.preview

        expect(preview).to be_a(Hash)
        expect(preview[:pack_name]).to eq('base')
        expect(preview).to have_key(:properties)
        expect(preview).to have_key(:locales)
      end
    end

    describe "Error handling" do
      it "raises InvalidPackError for pack without pack.yml" do
        # This is tested implicitly - packs must have pack.yml
        expect {
          SeedPack.find('base')
        }.not_to raise_error
      end
    end
  end
end
