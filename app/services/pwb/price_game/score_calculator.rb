# frozen_string_literal: true

module Pwb
  module PriceGame
    # Calculates score and feedback for price guesses
    # Based on percentage difference between guessed and actual price
    class ScoreCalculator
      SCORE_BRACKETS = [
        { max_diff: 5,   score: 100, feedback_key: "excellent" },
        { max_diff: 10,  score: 90,  feedback_key: "amazing" },
        { max_diff: 15,  score: 80,  feedback_key: "great" },
        { max_diff: 20,  score: 70,  feedback_key: "very_close" },
        { max_diff: 25,  score: 60,  feedback_key: "good" },
        { max_diff: 35,  score: 50,  feedback_key: "not_bad" },
        { max_diff: 50,  score: 40,  feedback_key: "keep_trying" },
        { max_diff: 75,  score: 30,  feedback_key: "room_for_improvement" },
        { max_diff: 100, score: 20,  feedback_key: "way_off" },
        { max_diff: Float::INFINITY, score: 10, feedback_key: "better_luck" }
      ].freeze

      attr_reader :guessed_cents, :actual_cents, :percentage_diff, :score, :bracket

      def initialize(guessed_cents:, actual_cents:)
        @guessed_cents = guessed_cents.to_i
        @actual_cents = actual_cents.to_i
        calculate
      end

      def calculate
        return zero_result if @actual_cents.zero?

        @percentage_diff = ((@guessed_cents.to_f - @actual_cents) / @actual_cents * 100).round(2)
        abs_diff = @percentage_diff.abs
        @bracket = SCORE_BRACKETS.find { |b| abs_diff <= b[:max_diff] }
        @score = @bracket[:score]
      end

      def feedback_message
        return I18n.t("price_game.feedback.invalid") if @bracket.nil?

        direction = @percentage_diff.positive? ? "above" : "below"
        abs_diff = @percentage_diff.abs.round(1)

        I18n.t(
          "price_game.feedback.#{@bracket[:feedback_key]}",
          diff: abs_diff,
          direction: I18n.t("price_game.direction.#{direction}"),
          default: default_feedback_message(abs_diff, direction)
        )
      end

      def emoji
        case @score
        when 90..100 then "🎉"
        when 70..89  then "👏"
        when 50..69  then "👍"
        when 30..49  then "🤔"
        else "💪"
        end
      end

      def result
        {
          score: @score,
          percentage_diff: @percentage_diff,
          feedback: feedback_message,
          emoji: emoji
        }
      end

      private

      def zero_result
        @percentage_diff = 0
        @score = 0
        @bracket = nil
      end

      def default_feedback_message(abs_diff, direction)
        messages = {
          "excellent" => "Excellent! Only #{abs_diff}% #{direction} the actual price!",
          "amazing" => "Amazing guess! #{abs_diff}% #{direction}.",
          "great" => "Great guess! #{abs_diff}% #{direction}.",
          "very_close" => "Very close! #{abs_diff}% #{direction}.",
          "good" => "Good effort! #{abs_diff}% #{direction}.",
          "not_bad" => "Not bad! #{abs_diff}% #{direction}.",
          "keep_trying" => "Keep trying! #{abs_diff}% #{direction}.",
          "room_for_improvement" => "Room for improvement. #{abs_diff}% #{direction}.",
          "way_off" => "Way off! #{abs_diff}% #{direction}.",
          "better_luck" => "Better luck next time! #{abs_diff}% #{direction}."
        }
        messages[@bracket&.dig(:feedback_key)] || "#{abs_diff}% #{direction} the actual price."
      end
    end
  end
end
