# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Video::ScriptGenerator do
  let(:website) { create(:pwb_website) }
  let(:property) do
    create(:pwb_realty_asset, :with_photos, website: website).tap do |asset|
      # Add more photos to meet minimum requirement
      create_list(:pwb_prop_photo, 3, realty_asset_id: asset.id)
    end
  end

  # Mock LLM response structure (RubyLLM::Message format)
  let(:mock_llm_response) do
    double(
      'RubyLLM::Message',
      content: mock_json_response,
      input_tokens: 200,
      output_tokens: 300,
      role: :assistant
    )
  end

  let(:mock_json_response) do
    {
      script: 'Welcome to this stunning 2-bedroom apartment in Test City. This beautiful home features spacious living areas and modern amenities. Contact us today to schedule a viewing.',
      scenes: [
        { photo_index: 0, duration: 5, caption: 'Welcome', transition: 'fade' },
        { photo_index: 1, duration: 5, caption: 'Living Room', transition: 'slide' },
        { photo_index: 2, duration: 5, caption: 'Kitchen', transition: 'slide' },
        { photo_index: 3, duration: 5, caption: 'Bedroom', transition: 'slide' },
        { photo_index: 4, duration: 5, caption: 'Contact Us', transition: 'fade' }
      ],
      music_mood: 'corporate, uplifting',
      estimated_duration: 25,
      word_count: 35
    }.to_json
  end

  # Mock chat instance that returns the response when asked
  let(:mock_chat_instance) do
    instance = double('RubyLLM::Chat')
    allow(instance).to receive(:with_instructions).and_return(instance)
    allow(instance).to receive(:ask).and_return(mock_llm_response)
    instance
  end

  before do
    # Enable AI by setting API key
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('test-api-key')
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', anything).and_return('test-api-key')

    # Mock the RubyLLM.chat call to return a chat instance
    allow(RubyLLM).to receive(:chat).and_return(mock_chat_instance)
  end

  describe '#initialize' do
    it 'accepts a property and optional parameters' do
      generator = described_class.new(property: property)
      expect(generator).to be_a(described_class)
    end

    it 'defaults to professional style' do
      generator = described_class.new(property: property)
      expect(generator.send(:style)).to eq(:professional)
    end

    it 'accepts valid styles' do
      %i[professional luxury casual energetic minimal].each do |style|
        generator = described_class.new(property: property, style: style)
        expect(generator.send(:style)).to eq(style)
      end
    end

    it 'passes website to the AI base service' do
      generator = described_class.new(
        property: property,
        options: { website: website }
      )

      # The website should be accessible via the parent class
      expect(generator.instance_variable_get(:@website)).to eq(website)
    end

    it 'passes user to the AI base service' do
      user = create(:pwb_user)
      generator = described_class.new(
        property: property,
        options: { website: website, user: user }
      )

      expect(generator.instance_variable_get(:@user)).to eq(user)
    end
  end

  describe 'AI configuration' do
    context 'without website and without ENV API key' do
      before do
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      end

      it 'raises ConfigurationError when generate is called' do
        generator = described_class.new(property: property)

        expect { generator.generate }.to raise_error(
          Ai::ConfigurationError,
          /AI is not configured/
        )
      end
    end

    context 'with website integration' do
      let!(:integration) do
        create(:pwb_website_integration, :anthropic, website: website)
      end

      before do
        # Remove ENV fallback to ensure integration is used
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      end

      it 'uses the website integration for configuration' do
        generator = described_class.new(
          property: property,
          options: { website: website }
        )

        # Should not raise ConfigurationError because website has integration
        expect { generator.generate }.not_to raise_error
      end

      it 'looks up integration via website' do
        generator = described_class.new(
          property: property,
          options: { website: website }
        )

        expect(generator.instance_variable_get(:@integration)).to eq(integration)
      end
    end

    context 'with ENV API key fallback' do
      it 'uses ENV when website has no integration' do
        generator = described_class.new(
          property: property,
          options: { website: website }
        )

        # ENV is mocked to return 'test-api-key', so this should work
        expect { generator.generate }.not_to raise_error
      end
    end
  end

  describe '#generate' do
    subject(:result) do
      described_class.new(
        property: property,
        options: { website: website }
      ).generate
    end

    it 'returns a hash with script data' do
      expect(result).to be_a(Hash)
      expect(result).to have_key(:script)
      expect(result).to have_key(:scenes)
      expect(result).to have_key(:music_mood)
    end

    it 'extracts script from response' do
      expect(result[:script]).to include('stunning 2-bedroom apartment')
    end

    it 'extracts scenes from response' do
      expect(result[:scenes]).to be_an(Array)
      expect(result[:scenes].length).to eq(5)
      expect(result[:scenes].first[:photo_index]).to eq(0)
    end

    it 'extracts music_mood from response' do
      expect(result[:music_mood]).to include('uplifting')
    end

    it 'includes estimated_duration' do
      expect(result[:estimated_duration]).to eq(25)
    end

    it 'includes word_count' do
      expect(result[:word_count]).to eq(35)
    end

    context 'with different styles' do
      Video::ScriptGenerator::STYLE_CONFIGS.keys.each do |style|
        it "generates script for #{style} style" do
          result = described_class.new(
            property: property,
            style: style,
            options: { website: website }
          ).generate

          expect(result[:script]).to be_present
        end
      end
    end

    context 'with custom options' do
      it 'respects duration_target option' do
        generator = described_class.new(
          property: property,
          options: { website: website, duration_target: 90 }
        )

        expect(generator.send(:options)[:duration_target]).to eq(90)
      end

      it 'respects include_price option' do
        generator = described_class.new(
          property: property,
          options: { website: website, include_price: false }
        )

        expect(generator.send(:options)[:include_price]).to be(false)
      end

      it 'respects max_photos option' do
        generator = described_class.new(
          property: property,
          options: { website: website, max_photos: 5 }
        )

        expect(generator.send(:options)[:max_photos]).to eq(5)
      end
    end
  end

  describe 'JSON parse error handling' do
    let(:mock_llm_response) do
      double(
        'RubyLLM::Message',
        content: 'This is not valid JSON',
        input_tokens: 100,
        output_tokens: 50,
        role: :assistant
      )
    end

    it 'returns fallback result on JSON parse error' do
      result = described_class.new(
        property: property,
        options: { website: website }
      ).generate

      expect(result[:script]).to include('Welcome to this beautiful property')
      expect(result[:scenes]).to be_an(Array)
    end

    it 'logs the JSON parse error' do
      expect(Rails.logger).to receive(:error).with(/JSON parse error/)

      described_class.new(
        property: property,
        options: { website: website }
      ).generate
    end
  end

  describe 'multi-tenant isolation' do
    let(:other_website) { create(:pwb_website) }
    let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }
    let!(:other_integration) { create(:pwb_website_integration, :anthropic, website: other_website) }

    before do
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
    end

    it 'uses the correct website integration' do
      generator = described_class.new(
        property: property,
        options: { website: website }
      )

      expect(generator.instance_variable_get(:@integration)).to eq(integration)
      expect(generator.instance_variable_get(:@integration)).not_to eq(other_integration)
    end

    it 'does not use integration from another website' do
      # Property belongs to website, but we pass other_website
      # This simulates a misconfiguration that should be caught
      generator = described_class.new(
        property: property,
        options: { website: other_website }
      )

      expect(generator.instance_variable_get(:@integration)).to eq(other_integration)
      expect(generator.instance_variable_get(:@website)).to eq(other_website)
    end
  end
end
