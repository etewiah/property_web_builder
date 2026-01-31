# frozen_string_literal: true

require 'rails_helper'

# These tests verify that AI error classes are properly autoloaded.
# They must reference the error constants directly without loading
# other AI services first, to catch Zeitwerk autoloading issues.
RSpec.describe 'Ai::Error classes' do
  describe Ai::Error do
    it 'can be raised' do
      expect { raise Ai::Error, 'test error' }.to raise_error(Ai::Error, 'test error')
    end
  end

  describe Ai::ConfigurationError do
    it 'can be raised' do
      expect { raise Ai::ConfigurationError, 'missing API key' }.to raise_error(Ai::ConfigurationError)
    end

    it 'is a subclass of Ai::Error' do
      expect(Ai::ConfigurationError.ancestors).to include(Ai::Error)
    end
  end

  describe Ai::ApiError do
    it 'can be raised' do
      expect { raise Ai::ApiError, 'API failed' }.to raise_error(Ai::ApiError)
    end

    it 'is a subclass of Ai::Error' do
      expect(Ai::ApiError.ancestors).to include(Ai::Error)
    end
  end

  describe Ai::TimeoutError do
    it 'can be raised' do
      expect { raise Ai::TimeoutError, 'request timed out' }.to raise_error(Ai::TimeoutError)
    end

    it 'is a subclass of Ai::Error' do
      expect(Ai::TimeoutError.ancestors).to include(Ai::Error)
    end
  end

  describe Ai::ContentPolicyError do
    it 'can be raised' do
      expect { raise Ai::ContentPolicyError, 'content blocked' }.to raise_error(Ai::ContentPolicyError)
    end

    it 'is a subclass of Ai::Error' do
      expect(Ai::ContentPolicyError.ancestors).to include(Ai::Error)
    end
  end

  describe Ai::RateLimitError do
    it 'can be raised' do
      expect { raise Ai::RateLimitError, 'rate limited' }.to raise_error(Ai::RateLimitError)
    end

    it 'is a subclass of Ai::Error' do
      expect(Ai::RateLimitError.ancestors).to include(Ai::Error)
    end

    it 'has a default retry_after of 60 seconds' do
      error = Ai::RateLimitError.new('rate limited')
      expect(error.retry_after).to eq(60)
    end

    it 'accepts a custom retry_after value' do
      error = Ai::RateLimitError.new('rate limited', retry_after: 120)
      expect(error.retry_after).to eq(120)
    end
  end
end
