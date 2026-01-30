# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::CmaGenerator, type: :service do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, website: website) }
  let(:subject_property) do
    create(:pwb_realty_asset, :with_location, :with_sale_listing,
           website: website,
           count_bedrooms: 3,
           count_bathrooms: 2,
           constructed_area: 150.0,
           year_construction: 2010,
           city: 'Test City',
           street_address: '123 Main St')
  end

  describe '#generate' do
    context 'when no comparable properties exist' do
      before do
        Pwb::ListedProperty.refresh(concurrently: false)
      end

      it 'creates a report' do
        generator = described_class.new(
          property: subject_property,
          website: website,
          user: user,
          options: { generate_pdf: false }
        )

        result = generator.generate

        expect(result.report).to be_persisted
        expect(result.report.report_type).to eq('cma')
      end

      it 'returns success with warning' do
        generator = described_class.new(
          property: subject_property,
          website: website,
          options: { generate_pdf: false }
        )

        result = generator.generate

        expect(result.success?).to be true
        expect(result.error).to include('No comparable properties found')
      end
    end

    context 'when comparable properties exist' do
      let!(:comparable) do
        create(:pwb_realty_asset, :with_location, :with_sale_listing,
               website: website,
               count_bedrooms: 3,
               count_bathrooms: 2,
               constructed_area: 145.0,
               year_construction: 2012,
               prop_type_key: subject_property.prop_type_key,
               latitude: subject_property.latitude + 0.001,
               longitude: subject_property.longitude + 0.001)
      end

      before do
        Pwb::ListedProperty.refresh(concurrently: false)
        allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
        allow_any_instance_of(Ai::BaseService).to receive(:ensure_configured!).and_return(true)
      end

      context 'with successful AI generation' do
        let(:mock_response) do
          double(
            content: {
              executive_summary: 'Property is well-positioned.',
              market_position: 'Above average.',
              pricing_rationale: 'Based on comparables.',
              strengths: ['Good location'],
              considerations: ['Minor updates needed'],
              recommendation: 'List at $360,000',
              time_to_sell_estimate: '30 days',
              suggested_price_low_cents: 340_000_00,
              suggested_price_high_cents: 380_000_00,
              confidence_level: 'high'
            }.to_json,
            input_tokens: 1500,
            output_tokens: 500
          )
        end

        before do
          allow_any_instance_of(Reports::CmaInsightsGenerator).to receive(:chat).and_return(mock_response)
        end

        it 'creates a completed report' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            user: user,
            options: { generate_pdf: false }
          )

          result = generator.generate

          expect(result.success?).to be true
          expect(result.report.status).to eq('completed')
        end

        it 'includes comparables in result' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          result = generator.generate

          expect(result.comparables).to be_an(Array)
          expect(result.comparables.length).to be > 0
        end

        it 'includes statistics in result' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          result = generator.generate

          expect(result.statistics).to be_present
        end

        it 'includes AI insights in result' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          result = generator.generate

          expect(result.insights).to be_a(Hash)
          expect(result.insights[:executive_summary]).to be_present
        end

        it 'stores insights in the report' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          result = generator.generate

          expect(result.report.ai_insights).to be_present
          expect(result.report.executive_summary).to be_present
        end

        it 'stores suggested price in the report' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          result = generator.generate

          expect(result.report.suggested_price_low_cents).to be_present
          expect(result.report.suggested_price_high_cents).to be_present
        end

        it 'enqueues PDF generation when requested' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: true }
          )

          expect {
            generator.generate
          }.to have_enqueued_job(GenerateReportPdfJob)
        end

        it 'skips PDF generation when not requested' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          expect {
            generator.generate
          }.not_to have_enqueued_job(GenerateReportPdfJob)
        end
      end

      context 'with AI configuration error' do
        before do
          allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(false)
          allow_any_instance_of(Ai::BaseService).to receive(:ensure_configured!)
            .and_raise(Ai::ConfigurationError, 'AI not configured')
        end

        it 'raises ConfigurationError' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          expect { generator.generate }.to raise_error(Ai::ConfigurationError)
        end

        it 'leaves report in draft status' do
          generator = described_class.new(
            property: subject_property,
            website: website,
            options: { generate_pdf: false }
          )

          begin
            generator.generate
          rescue Ai::ConfigurationError
            # Expected
          end

          report = Pwb::MarketReport.last
          expect(report.status).to eq('draft')
        end
      end
    end

    context 'with custom options' do
      before do
        Pwb::ListedProperty.refresh(concurrently: false)
      end

      it 'uses custom title' do
        generator = described_class.new(
          property: subject_property,
          website: website,
          options: { title: 'Custom CMA Title', generate_pdf: false }
        )

        result = generator.generate

        expect(result.report.title).to eq('Custom CMA Title')
      end

      it 'uses custom radius' do
        generator = described_class.new(
          property: subject_property,
          website: website,
          options: { radius_km: 5, generate_pdf: false }
        )

        result = generator.generate

        expect(result.report.radius_km).to eq(5)
      end

      it 'uses custom branding' do
        branding = {
          agent_name: 'John Smith',
          company_name: 'Premier Realty'
        }

        generator = described_class.new(
          property: subject_property,
          website: website,
          options: { branding: branding, generate_pdf: false }
        )

        result = generator.generate

        expect(result.report.agent_name).to eq('John Smith')
        expect(result.report.company_name).to eq('Premier Realty')
      end
    end
  end

  describe 'multi-tenancy' do
    let(:other_website) { create(:pwb_website) }

    it 'creates report scoped to correct website' do
      Pwb::ListedProperty.refresh(concurrently: false)

      generator = described_class.new(
        property: subject_property,
        website: website,
        options: { generate_pdf: false }
      )

      result = generator.generate

      expect(result.report.website_id).to eq(website.id)
      expect(other_website.market_reports).not_to include(result.report)
    end
  end
end
