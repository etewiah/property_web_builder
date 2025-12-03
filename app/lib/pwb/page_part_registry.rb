# frozen_string_literal: true

module Pwb
  class PagePartRegistry
    @definitions = {}

    class << self
      def register(definition)
        @definitions[definition.key] = definition
      end

      def find(key)
        @definitions[key.to_sym]
      end

      def all
        @definitions.values
      end

      def clear!
        @definitions = {}
      end
    end
  end
end
