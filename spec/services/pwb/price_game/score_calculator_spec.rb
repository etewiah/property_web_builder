# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PriceGame::ScoreCalculator do
  describe "#calculate" do
    context "when guess is exact" do
      it "returns score of 100" do
        calc = described_class.new(guessed_cents: 300_000_00, actual_cents: 300_000_00)
        expect(calc.score).to eq(100)
        expect(calc.percentage_diff).to eq(0.0)
      end
    end

    context "when guess is within 5%" do
      it "returns score of 100" do
        calc = described_class.new(guessed_cents: 290_000_00, actual_cents: 300_000_00)
        expect(calc.score).to eq(100)
        expect(calc.percentage_diff).to be_between(-5, 5)
      end
    end

    context "when guess is within 10%" do
      it "returns score of 90" do
        calc = described_class.new(guessed_cents: 275_000_00, actual_cents: 300_000_00)
        expect(calc.score).to eq(90)
      end
    end

    context "when guess is within 15%" do
      it "returns score of 80" do
        calc = described_class.new(guessed_cents: 260_000_00, actual_cents: 300_000_00)
        expect(calc.score).to eq(80)
      end
    end

    context "when guess is within 20%" do
      it "returns score of 70" do
        calc = described_class.new(guessed_cents: 250_000_00, actual_cents: 300_000_00)
        expect(calc.score).to eq(70)
      end
    end

    context "when guess is way off (>100%)" do
      it "returns score of 10" do
        calc = described_class.new(guessed_cents: 700_000_00, actual_cents: 300_000_00)
        expect(calc.score).to eq(10)
      end
    end

    context "when actual price is zero" do
      it "returns score of 0" do
        calc = described_class.new(guessed_cents: 300_000_00, actual_cents: 0)
        expect(calc.score).to eq(0)
      end
    end
  end

  describe "#feedback_message" do
    it "returns appropriate feedback for high scores" do
      calc = described_class.new(guessed_cents: 300_000_00, actual_cents: 300_000_00)
      expect(calc.feedback_message).to include("Excellent")
    end

    it "includes direction (above/below)" do
      calc = described_class.new(guessed_cents: 350_000_00, actual_cents: 300_000_00)
      expect(calc.feedback_message).to include("above")

      calc = described_class.new(guessed_cents: 250_000_00, actual_cents: 300_000_00)
      expect(calc.feedback_message).to include("below")
    end
  end

  describe "#emoji" do
    it "returns celebration emoji for high scores" do
      calc = described_class.new(guessed_cents: 300_000_00, actual_cents: 300_000_00)
      expect(calc.emoji).to eq("🎉")
    end

    it "returns thinking emoji for medium-low scores" do
      # 200k vs 300k is 33% off, which gives score of 50 (not_bad)
      calc = described_class.new(guessed_cents: 200_000_00, actual_cents: 300_000_00)
      # Score 50 is in 50-69 range, which should give 👍
      expect(calc.emoji).to eq("👍")
    end

    it "returns thinking emoji for low-medium scores" do
      # 150k vs 300k is 50% off, which gives score of 40
      calc = described_class.new(guessed_cents: 150_000_00, actual_cents: 300_000_00)
      expect(calc.emoji).to eq("🤔")
    end

    it "returns muscle emoji for low scores" do
      calc = described_class.new(guessed_cents: 50_000_00, actual_cents: 300_000_00)
      expect(calc.emoji).to eq("💪")
    end
  end

  describe "#result" do
    it "returns a hash with all result data" do
      calc = described_class.new(guessed_cents: 280_000_00, actual_cents: 300_000_00)
      result = calc.result

      expect(result).to include(
        score: be_a(Integer),
        percentage_diff: be_a(Float),
        feedback: be_a(String),
        emoji: be_a(String)
      )
    end
  end
end
