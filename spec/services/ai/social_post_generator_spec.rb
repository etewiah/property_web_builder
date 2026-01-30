# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::SocialPostGenerator, type: :service do
  let(:website) { create(:website) }
  let(:property) do
    create(:pwb_realty_asset,
      website: website,
      prop_type_key: 'apartment',
      count_bedrooms: 3,
      count_bathrooms: 2,
      city: 'Barcelona',
      region: 'Catalonia'
    )
  end

  describe '#initialize' do
    it 'accepts property and platform' do
      generator = described_class.new(property: property, platform: :instagram)

      expect(generator.property).to eq(property)
      expect(generator.platform).to eq(:instagram)
    end

    it 'sets default options' do
      generator = described_class.new(property: property, platform: :instagram)

      expect(generator.options[:post_type]).to eq('feed')
      expect(generator.options[:category]).to eq('just_listed')
      expect(generator.options[:locale]).to eq('en')
    end

    it 'accepts custom options' do
      generator = described_class.new(
        property: property,
        platform: :linkedin,
        options: { category: 'price_drop', locale: 'es' }
      )

      expect(generator.options[:category]).to eq('price_drop')
      expect(generator.options[:locale]).to eq('es')
    end
  end

  describe 'platform configurations' do
    it 'has configuration for all supported platforms' do
      %i[instagram facebook linkedin twitter tiktok].each do |platform|
        config = described_class::PLATFORM_CONFIGS[platform]
        expect(config).to be_present
        expect(config[:tone]).to be_present
        expect(config[:emoji_level]).to be_present
        expect(config[:hashtag_count]).to be_present
      end
    end

    it 'has professional tone for LinkedIn' do
      config = described_class::PLATFORM_CONFIGS[:linkedin]
      expect(config[:tone]).to eq('professional')
      expect(config[:emoji_level]).to eq(:low)
    end

    it 'has engaging tone for Instagram' do
      config = described_class::PLATFORM_CONFIGS[:instagram]
      expect(config[:tone]).to eq('engaging and visual')
      expect(config[:emoji_level]).to eq(:high)
    end
  end

  describe '#generate' do
    let(:generator) { described_class.new(property: property, platform: :instagram) }

    context 'when AI is not configured' do
      before do
        allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(false)
      end

      it 'raises ConfigurationError' do
        expect { generator.generate }.to raise_error(Ai::ConfigurationError)
      end
    end

    context 'when AI is configured', :vcr do
      let(:mock_response) do
        double('response',
          content: '{"caption": "Check out this stunning 3-bedroom apartment in Barcelona!", "hashtags": "#realestate #barcelona #apartment", "suggested_photos": ["exterior", "living_room"], "best_posting_time": "10am local time"}',
          input_tokens: 500,
          output_tokens: 100
        )
      end

      before do
        allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
        allow_any_instance_of(Ai::BaseService).to receive(:configure_ruby_llm!)
        allow_any_instance_of(described_class).to receive(:chat).and_return(mock_response)
      end

      it 'creates an AI generation request' do
        expect { generator.generate }.to change(Pwb::AiGenerationRequest, :count).by(1)
      end

      it 'creates a social media post' do
        expect { generator.generate }.to change(Pwb::SocialMediaPost, :count).by(1)
      end

      it 'returns a successful result' do
        result = generator.generate

        expect(result.success?).to be true
        expect(result.post).to be_a(Pwb::SocialMediaPost)
        expect(result.post.platform).to eq('instagram')
        expect(result.post.caption).to include('Barcelona')
      end

      it 'stores the post as draft' do
        result = generator.generate

        expect(result.post.status).to eq('draft')
      end

      it 'marks the request as completed' do
        result = generator.generate
        request = Pwb::AiGenerationRequest.find(result.request_id)

        expect(request.status).to eq('completed')
        expect(request.request_type).to eq('social_post')
      end
    end

    context 'when AI returns an error' do
      before do
        allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
        allow_any_instance_of(Ai::BaseService).to receive(:configure_ruby_llm!)
        allow_any_instance_of(described_class).to receive(:chat).and_raise(Ai::ApiError.new('API failed'))
      end

      it 'returns a failed result' do
        result = generator.generate

        expect(result.success?).to be false
        expect(result.error).to eq('API failed')
      end

      it 'marks the request as failed' do
        result = generator.generate
        request = Pwb::AiGenerationRequest.find(result.request_id)

        expect(request.status).to eq('failed')
        expect(request.error_message).to eq('API failed')
      end
    end
  end

  describe '#generate_batch' do
    let(:generator) { described_class.new(property: property, platform: :instagram) }

    let(:mock_response) do
      double('response',
        content: '{"caption": "Test caption", "hashtags": "#test", "suggested_photos": [], "best_posting_time": "10am"}',
        input_tokens: 100,
        output_tokens: 50
      )
    end

    before do
      allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
      allow_any_instance_of(Ai::BaseService).to receive(:configure_ruby_llm!)
      allow_any_instance_of(described_class).to receive(:chat).and_return(mock_response)
    end

    it 'generates posts for multiple platforms' do
      results = generator.generate_batch(platforms: [:instagram, :facebook, :linkedin])

      expect(results.length).to eq(3)
      expect(results.all?(&:success?)).to be true

      platforms = results.map { |r| r.post.platform }
      expect(platforms).to contain_exactly('instagram', 'facebook', 'linkedin')
    end

    it 'uses default platforms if none specified' do
      results = generator.generate_batch

      expect(results.length).to eq(3)
    end
  end

  describe 'category instructions' do
    let(:generator) { described_class.new(property: property, platform: :instagram) }

    it 'provides just_listed instructions' do
      generator = described_class.new(property: property, platform: :instagram, options: { category: 'just_listed' })
      instructions = generator.send(:category_instructions)

      expect(instructions).to include('Excitement')
      expect(instructions).to include('unique features')
    end

    it 'provides price_drop instructions' do
      generator = described_class.new(property: property, platform: :instagram, options: { category: 'price_drop' })
      instructions = generator.send(:category_instructions)

      expect(instructions).to include('value')
      expect(instructions).to include('reduction')
    end

    it 'provides open_house instructions' do
      generator = described_class.new(property: property, platform: :instagram, options: { category: 'open_house' })
      instructions = generator.send(:category_instructions)

      expect(instructions).to include('event')
      expect(instructions).to include('date/time')
    end

    it 'provides sold instructions' do
      generator = described_class.new(property: property, platform: :instagram, options: { category: 'sold' })
      instructions = generator.send(:category_instructions)

      expect(instructions).to include('Celebrate')
      expect(instructions).to include('credibility')
    end
  end

  describe 'platform-specific aspect ratios' do
    let(:generator) { described_class.new(property: property, platform: :instagram) }

    it 'returns 1:1 for Instagram feed' do
      generator = described_class.new(property: property, platform: :instagram, options: { post_type: 'feed' })
      expect(generator.send(:aspect_ratio_for_platform)).to eq('1:1')
    end

    it 'returns 9:16 for Instagram story' do
      generator = described_class.new(property: property, platform: :instagram, options: { post_type: 'story' })
      expect(generator.send(:aspect_ratio_for_platform)).to eq('9:16')
    end

    it 'returns 16:9 for Twitter' do
      generator = described_class.new(property: property, platform: :twitter)
      expect(generator.send(:aspect_ratio_for_platform)).to eq('16:9')
    end

    it 'returns 9:16 for TikTok' do
      generator = described_class.new(property: property, platform: :tiktok)
      expect(generator.send(:aspect_ratio_for_platform)).to eq('9:16')
    end
  end
end
