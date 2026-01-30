# frozen_string_literal: true

# RubyLLM configuration for AI-powered content generation
#
# Supported providers:
#   - Anthropic (Claude models) - default
#   - OpenAI (GPT models) - optional fallback
#
# Environment variables:
#   ANTHROPIC_API_KEY - Required for Claude models
#   OPENAI_API_KEY - Optional, for OpenAI fallback
#
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.default_model = 'claude-sonnet-4-20250514'
end if defined?(RubyLLM)
