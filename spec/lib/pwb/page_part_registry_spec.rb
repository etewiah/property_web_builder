# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PagePartRegistry do
  after do
    described_class.clear!
  end

  describe ".register" do
    it "registers a definition" do
      definition = double("definition", key: :test_part)
      described_class.register(definition)

      expect(described_class.find(:test_part)).to eq(definition)
    end
  end

  describe ".find" do
    it "returns registered definition by key" do
      definition = double("definition", key: :test_part)
      described_class.register(definition)

      expect(described_class.find(:test_part)).to eq(definition)
    end

    it "returns nil for unknown keys" do
      expect(described_class.find(:unknown)).to be_nil
    end
  end

  describe ".all" do
    it "returns all registered definitions" do
      def1 = double("definition1", key: :part1)
      def2 = double("definition2", key: :part2)

      described_class.register(def1)
      described_class.register(def2)

      expect(described_class.all).to contain_exactly(def1, def2)
    end

    it "returns empty array when no definitions registered" do
      expect(described_class.all).to eq([])
    end
  end

  describe ".clear!" do
    it "removes all registered definitions" do
      definition = double("definition", key: :test_part)
      described_class.register(definition)

      described_class.clear!

      expect(described_class.all).to be_empty
      expect(described_class.find(:test_part)).to be_nil
    end
  end
end
