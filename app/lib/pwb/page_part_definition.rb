# frozen_string_literal: true

module Pwb
  class PagePartDefinition
    attr_reader :key, :fields

    def initialize(key)
      @key = key
      @fields = []
    end

    def self.define(key, &block)
      definition = new(key)
      definition.instance_eval(&block)
      definition.validate_template!
      Pwb::PagePartRegistry.register(definition)
    end

    def field(name, type:, label: nil)
      @fields << { name: name, type: type, label: label || name.to_s.humanize }
    end

    def validate_template!
      template_path = Rails.root.join("app/views/pwb/page_parts/#{key}.liquid")
      return unless File.exist?(template_path)

      template_content = File.read(template_path)

      @fields.each do |field|
        field_name = field[:name]
        # Check for various Liquid variable formats
        unless template_content.include?("{{ #{field_name} }}") ||
               template_content.include?("{{#{field_name}}}") ||
               template_content.match?(/\{\%\s*if\s+#{field_name}\s*\%\}/)
          Rails.logger.warn "Field '#{field_name}' not found in template for #{key}"
        end
      end
    end

    def to_editor_config
      {
        key: @key,
        fields: @fields
      }
    end
  end
end
