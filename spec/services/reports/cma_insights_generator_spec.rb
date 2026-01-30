# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::CmaInsightsGenerator, type: :service do
  let(:website) { create(:pwb_website) }
  let(:subject_property) do
    create(:pwb_realty_asset, :with_location,
           website: website,
           count_bedrooms: 3,
           count_bathrooms: 2,
           constructed_area: 150.0,
           year_construction: 2010,
           city: 'Test City',
           street_address: '123 Main St')
  end
  let(:report) do
    create(:pwb_market_report,
           website: website,
           subject_property: subject_property,
           suggested_price_currency: 'USD')
  end
  let(:comparables) do
    [
      {
        id: SecureRandom.uuid,
        address: '125 Main St, Test City',
        price_cents: 350_000_00,
        bedrooms: 3,
        bathrooms: 2,
        constructed_area: 145,
        year_built: 2012,
        similarity_score: 92,
        adjustments: { size: { difference: 5, adjustment_cents: 750_00 } },
        adjusted_price_cents: 350_750_00,
        distance_km: 0.5
      },
      {
        id: SecureRandom.uuid,
        address: '200 Oak Ave, Test City',
        price_cents: 380_000_00,
        bedrooms: 4,
        bathrooms: 2,
        constructed_area: 160,
        year_built: 2008,
        similarity_score: 85,
        adjustments: { bedrooms: { difference: -1, adjustment_cents: -15_000_00 } },
        adjusted_price_cents: 365_000_00,
        distance_km: 0.8
      }
    ]
  end
  let(:statistics) do
    Reports::StatisticsCalculator::Result.new(
      average_price_cents: 365_000_00,
      median_price_cents: 365_000_00,
      price_per_sqft_cents: 2433_00,
      price_range: { low_cents: 350_000_00, high_cents: 380_000_00 },
      adjusted_average_cents: 357_875_00,
      adjusted_median_cents: 357_875_00,
      comparable_count: 2,
      currency: 'USD',
      statistics: {
        average_price: 365_000_00,
        median_price: 365_000_00,
        adjusted_average_price: 357_875_00,
        adjusted_median_price: 357_875_00,
        price_per_sqft: 2433_00,
        comparable_count: 2,
        average_similarity: 88.5
      }
    )
  end

  describe '#generate' do
    context 'when AI is not configured' do
      before do
        allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(false)
      end

      it 'raises ConfigurationError' do
        generator = described_class.new(
          report: report,
          comparables: comparables,
          statistics: statistics
        )

        expect { generator.generate }.to raise_error(Ai::ConfigurationError)
      end
    end

    context 'when AI is configured', :vcr do
      before do
        # Mock the AI configuration
        allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
        allow_any_instance_of(Ai::BaseService).to receive(:ensure_configured!).and_return(true)
      end

      context 'with successful AI response' do
        let(:mock_response) do
          double(
            content: {
              executive_summary: 'This property is well-positioned in the market.',
              market_position: 'Above average condition.',
              pricing_rationale: 'Based on 2 comparable sales.',
              strengths: ['Good location', 'Modern kitchen'],
              considerations: ['Limited parking'],
              recommendation: 'List at $360,000.',
              time_to_sell_estimate: '30-45 days',
              suggested_price_low_cents: 340_000_00,
              suggested_price_high_cents: 380_000_00,
              confidence_level: 'high'
            }.to_json,
            input_tokens: 1500,
            output_tokens: 500
          )
        end

        before do
          allow_any_instance_of(described_class).to receive(:chat).and_return(mock_response)
        end

        it 'returns a successful result' do
          generator = described_class.new(
            report: report,
            comparables: comparables,
            statistics: statistics
          )

          result = generator.generate

          expect(result.success?).to be true
        end

        it 'includes insights' do
          generator = described_class.new(
            report: report,
            comparables: comparables,
            statistics: statistics
          )

          result = generator.generate

          expect(result.insights).to include(
            :executive_summary,
            :market_position,
            :pricing_rationale,
            :strengths,
            :considerations,
            :recommendation
          )
        end

        it 'includes suggested price' do
          generator = described_class.new(
            report: report,
            comparables: comparables,
            statistics: statistics
          )

          result = generator.generate

          expect(result.suggested_price).to include(
            :low_cents,
            :high_cents,
            :currency
          )
        end

        it 'creates an AI generation request' do
          generator = described_class.new(
            report: report,
            comparables: comparables,
            statistics: statistics
          )

          expect {
            generator.generate
          }.to change(Pwb::AiGenerationRequest, :count).by(1)
        end

        it 'marks the request as completed' do
          generator = described_class.new(
            report: report,
            comparables: comparables,
            statistics: statistics
          )

          result = generator.generate
          request = Pwb::AiGenerationRequest.find(result.request_id)

          expect(request.status).to eq('completed')
          expect(request.output_data).to be_present
        end
      end

      context 'with AI error' do
        before do
          allow_any_instance_of(described_class).to receive(:chat)
            .and_raise(Ai::ApiError, 'AI service unavailable')
        end

        it 'returns a failed result' do
          generator = described_class.new(
            report: report,
            comparables: comparables,
            statistics: statistics
          )

          result = generator.generate

          expect(result.success?).to be false
          expect(result.error).to be_present
        end

        it 'marks the request as failed' do
          generator = described_class.new(
            report: report,
            comparables: comparables,
            statistics: statistics
          )

          result = generator.generate
          request = Pwb::AiGenerationRequest.find(result.request_id)

          expect(request.status).to eq('failed')
          expect(request.error_message).to be_present
        end
      end
    end
  end

  describe 'prompt building' do
    let(:generator) do
      described_class.new(
        report: report,
        comparables: comparables,
        statistics: statistics
      )
    end

    it 'includes subject property details' do
      prompt = generator.send(:user_prompt)

      expect(prompt).to include('123 Main St')
      expect(prompt).to include('Test City')
      expect(prompt).to include('Bedrooms: 3')
    end

    it 'includes comparable properties' do
      prompt = generator.send(:user_prompt)

      expect(prompt).to include('125 Main St')
      expect(prompt).to include('Comparable 1')
      expect(prompt).to include('Similarity Score: 92%')
    end

    it 'includes market statistics' do
      prompt = generator.send(:user_prompt)

      expect(prompt).to include('Average Price')
      expect(prompt).to include('Median Price')
    end
  end
end
