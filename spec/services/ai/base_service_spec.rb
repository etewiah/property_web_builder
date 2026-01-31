# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::BaseService do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user) }

  # Create a concrete subclass for testing since BaseService is abstract
  let(:test_service_class) do
    Class.new(described_class) do
      def test_chat(messages)
        chat(messages: messages)
      end

      def test_configured?
        configured?
      end

      def test_ensure_configured!
        ensure_configured!
      end

      def test_create_request(type:, input_data: {})
        create_generation_request(type: type, input_data: input_data)
      end
    end
  end

  describe '#initialize' do
    it 'accepts website and user' do
      service = test_service_class.new(website: website, user: user)

      expect(service.instance_variable_get(:@website)).to eq(website)
      expect(service.instance_variable_get(:@user)).to eq(user)
    end

    it 'allows nil website and user' do
      service = test_service_class.new

      expect(service.instance_variable_get(:@website)).to be_nil
      expect(service.instance_variable_get(:@user)).to be_nil
    end

    context 'with website integration' do
      let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

      it 'looks up the AI integration for the website' do
        service = test_service_class.new(website: website)

        expect(service.instance_variable_get(:@integration)).to eq(integration)
      end
    end

    context 'without website integration' do
      it 'sets integration to nil' do
        service = test_service_class.new(website: website)

        expect(service.instance_variable_get(:@integration)).to be_nil
      end
    end
  end

  describe '#configured?' do
    context 'with website integration that has credentials' do
      let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      end

      it 'returns true' do
        service = test_service_class.new(website: website)

        expect(service.test_configured?).to be true
      end
    end

    context 'with ENV ANTHROPIC_API_KEY' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('sk-test-key')
      end

      it 'returns true even without website' do
        service = test_service_class.new

        expect(service.test_configured?).to be true
      end

      it 'returns true with website but no integration' do
        service = test_service_class.new(website: website)

        expect(service.test_configured?).to be true
      end
    end

    context 'with ENV OPENAI_API_KEY' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('sk-openai-key')
      end

      it 'returns true' do
        service = test_service_class.new

        expect(service.test_configured?).to be true
      end
    end

    context 'without any configuration' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      end

      it 'returns false' do
        service = test_service_class.new

        expect(service.test_configured?).to be false
      end
    end
  end

  describe '#ensure_configured!' do
    context 'when configured' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('sk-test-key')
      end

      it 'does not raise' do
        service = test_service_class.new

        expect { service.test_ensure_configured! }.not_to raise_error
      end
    end

    context 'when not configured' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      end

      it 'raises ConfigurationError' do
        service = test_service_class.new

        expect { service.test_ensure_configured! }.to raise_error(
          Ai::ConfigurationError,
          /AI is not configured/
        )
      end
    end
  end

  describe '#chat' do
    let(:mock_llm_response) do
      double(
        'RubyLLM::Message',
        content: 'Test response',
        input_tokens: 100,
        output_tokens: 50,
        role: :assistant
      )
    end

    let(:mock_chat_instance) do
      instance = double('RubyLLM::Chat')
      allow(instance).to receive(:with_instructions).and_return(instance)
      allow(instance).to receive(:ask).and_return(mock_llm_response)
      instance
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('sk-test-key')
      allow(RubyLLM).to receive(:chat).and_return(mock_chat_instance)
    end

    it 'returns the LLM response' do
      service = test_service_class.new(website: website)
      messages = [{ role: 'user', content: 'Hello' }]

      response = service.test_chat(messages)

      expect(response.content).to eq('Test response')
    end

    it 'handles system messages with with_instructions' do
      service = test_service_class.new(website: website)
      messages = [
        { role: 'system', content: 'You are helpful' },
        { role: 'user', content: 'Hello' }
      ]

      expect(mock_chat_instance).to receive(:with_instructions).with('You are helpful')

      service.test_chat(messages)
    end

    it 'records usage on integration when present' do
      integration = create(:pwb_website_integration, :anthropic, website: website)
      service = test_service_class.new(website: website)

      # The service looks up integration on init, so we need to set expectation on the actual instance
      expect(service.instance_variable_get(:@integration)).to receive(:record_usage!)

      service.test_chat([{ role: 'user', content: 'Hello' }])
    end

    context 'error handling' do
      # RubyLLM errors take (response, message) as optional params
      it 'converts RubyLLM::RateLimitError to Ai::RateLimitError' do
        allow(mock_chat_instance).to receive(:ask).and_raise(RubyLLM::RateLimitError.new(nil, 'Rate limited'))
        service = test_service_class.new(website: website)

        expect { service.test_chat([{ role: 'user', content: 'Hello' }]) }
          .to raise_error(Ai::RateLimitError)
      end

      it 'converts RubyLLM::UnauthorizedError to Ai::ConfigurationError' do
        allow(mock_chat_instance).to receive(:ask).and_raise(RubyLLM::UnauthorizedError.new(nil, 'Invalid key'))
        service = test_service_class.new(website: website)

        expect { service.test_chat([{ role: 'user', content: 'Hello' }]) }
          .to raise_error(Ai::ConfigurationError, /Invalid API key/)
      end

      it 'converts RubyLLM::ForbiddenError to Ai::ContentPolicyError' do
        allow(mock_chat_instance).to receive(:ask).and_raise(RubyLLM::ForbiddenError.new(nil, 'Content blocked'))
        service = test_service_class.new(website: website)

        expect { service.test_chat([{ role: 'user', content: 'Hello' }]) }
          .to raise_error(Ai::ContentPolicyError)
      end

      it 'converts generic RubyLLM::Error to Ai::ApiError' do
        allow(mock_chat_instance).to receive(:ask).and_raise(RubyLLM::Error.new(nil, 'Some error'))
        service = test_service_class.new(website: website)

        expect { service.test_chat([{ role: 'user', content: 'Hello' }]) }
          .to raise_error(Ai::ApiError)
      end

      it 'converts Timeout::Error to Ai::TimeoutError' do
        allow(mock_chat_instance).to receive(:ask).and_raise(Timeout::Error.new('Timed out'))
        service = test_service_class.new(website: website)

        expect { service.test_chat([{ role: 'user', content: 'Hello' }]) }
          .to raise_error(Ai::TimeoutError)
      end

      it 'records errors on integration' do
        create(:pwb_website_integration, :anthropic, website: website)
        allow(mock_chat_instance).to receive(:ask).and_raise(RubyLLM::Error.new(nil, 'API failed'))
        service = test_service_class.new(website: website)

        # The service looks up integration on init, so we need to set expectation on the actual instance
        expect(service.instance_variable_get(:@integration)).to receive(:record_error!).with('API failed')

        expect { service.test_chat([{ role: 'user', content: 'Hello' }]) }
          .to raise_error(Ai::ApiError)
      end
    end
  end

  describe '#create_generation_request' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('sk-test-key')
    end

    it 'creates an AiGenerationRequest record' do
      service = test_service_class.new(website: website, user: user)

      expect {
        service.test_create_request(type: 'listing_description', input_data: { foo: 'bar' })
      }.to change(Pwb::AiGenerationRequest, :count).by(1)
    end

    it 'sets the correct attributes' do
      service = test_service_class.new(website: website, user: user)

      request = service.test_create_request(type: 'listing_description', input_data: { locale: 'en' })

      expect(request.website).to eq(website)
      expect(request.user).to eq(user)
      expect(request.request_type).to eq('listing_description')
      expect(request.ai_provider).to eq('anthropic')
      expect(request.status).to eq('pending')
    end
  end

  describe 'multi-tenant isolation' do
    let(:website1) { create(:pwb_website) }
    let(:website2) { create(:pwb_website) }
    let!(:integration1) { create(:pwb_website_integration, :anthropic, website: website1) }
    let!(:integration2) { create(:pwb_website_integration, :openai, website: website2) }

    it 'uses the correct integration for each website' do
      service1 = test_service_class.new(website: website1)
      service2 = test_service_class.new(website: website2)

      expect(service1.instance_variable_get(:@integration)).to eq(integration1)
      expect(service2.instance_variable_get(:@integration)).to eq(integration2)
    end

    it 'does not cross-contaminate integrations' do
      service1 = test_service_class.new(website: website1)

      expect(service1.instance_variable_get(:@integration)).not_to eq(integration2)
    end
  end

  describe 'OpenRouter integration' do
    let!(:integration) { create(:pwb_website_integration, :open_router, website: website) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
    end

    it 'uses OpenRouter integration when configured' do
      service = test_service_class.new(website: website)

      expect(service.instance_variable_get(:@integration)).to eq(integration)
      expect(service.instance_variable_get(:@integration).provider).to eq('open_router')
    end

    it 'reports as configured when OpenRouter integration exists' do
      service = test_service_class.new(website: website)

      expect(service.test_configured?).to be true
    end

    it 'provides OpenRouter credentials to RubyLLM' do
      service = test_service_class.new(website: website)

      # Verify the integration provides the right credentials for RubyLLM's
      # native OpenRouter support (openrouter_api_key config)
      expect(integration.credential(:api_key)).to eq('sk-or-test-key-12345')
      expect(integration.setting(:default_model)).to eq('anthropic/claude-3.5-sonnet')
    end
  end
end
