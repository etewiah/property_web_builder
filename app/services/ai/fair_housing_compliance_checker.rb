# frozen_string_literal: true

module Ai
  # Checks generated listing descriptions for Fair Housing Act compliance.
  #
  # The Fair Housing Act prohibits discriminatory language that could indicate
  # a preference or limitation based on:
  # - Race, color, national origin
  # - Religion
  # - Sex, gender identity, sexual orientation
  # - Familial status (families with children)
  # - Disability
  # - Age (in some jurisdictions)
  #
  # This checker scans text for potentially problematic phrases and flags them
  # for review. It's conservative and may produce false positives - the goal
  # is to catch potential issues before publication.
  #
  # Usage:
  #   checker = Ai::FairHousingComplianceChecker.new
  #   result = checker.check("Perfect for young professionals!")
  #   # => { compliant: false, violations: [{pattern: "young", match: "young", category: "age"}] }
  #
  class FairHousingComplianceChecker
    # Patterns that may indicate discriminatory preference
    # Organized by protected class category
    PROHIBITED_PATTERNS = {
      familial_status: [
        /\b(no\s+)?kids?\b/i,
        /\b(no\s+)?children\b/i,
        /\bfamil(y|ies)\s+(friendly|oriented|welcome)\b/i,
        /\badult\s+(only|community|living)\b/i,
        /\bsingles?\s+only\b/i,
        /\bcouples?\s+only\b/i,
        /\bmature\s+(couple|tenant|person)/i
      ],
      age: [
        /\bsenior(s)?\s+(only|community|living)\b/i,
        /\b(active\s+)?adult\s+55\+?\b/i,
        /\byoung\s+(professional|couple|person)\b/i,
        /\belderly\b/i,
        /\bretire[ed]?\s+(only|community)\b/i
      ],
      religion: [
        /\bnear\s+(church|mosque|synagogue|temple|cathedral)\b/i,
        /\b(christian|muslim|jewish|hindu|buddhist)\s+(family|community|neighborhood)\b/i
      ],
      national_origin: [
        /\b(english|spanish|chinese)\s+speaking\s+(only|preferred)\b/i,
        /\bamerican\s+(only|preferred)\b/i,
        /\bcitizen(s)?\s+(only|preferred)\b/i
      ],
      disability: [
        /\bable[\s-]?bodied\b/i,
        /\bno\s+(wheelchair|disability|handicap)\b/i,
        /\bmust\s+be\s+able\s+to\b/i
      ],
      gender: [
        /\b(female|male|women|men)\s+(only|preferred|tenant)\b/i,
        /\b(bachelor|bachelorette)\s+pad\b/i
      ],
      race: [
        # Be very careful with these - just flag certain contexts
        /\b(white|black|asian|hispanic)\s+(neighborhood|area|community)\b/i,
        /\bexclusive\s+(neighborhood|area|community)\b/i
      ]
    }.freeze

    # Phrases that are generally acceptable in context but should be reviewed
    REVIEW_SUGGESTED = [
      /\bwalk\s+to\b/i,          # Could be disability-related in some contexts
      /\bclose\s+to\s+schools\b/i, # Usually fine, but context matters
      /\bquiet\s+(neighborhood|area|community)\b/i  # Sometimes used as coded language
    ].freeze

    def initialize
      @violations = []
      @suggestions = []
    end

    # Check text for Fair Housing compliance
    #
    # @param text [String] The text to check
    # @return [Hash] Result with :compliant, :violations, and :suggestions keys
    #
    def check(text)
      @violations = []
      @suggestions = []

      return compliant_result if text.blank?

      check_prohibited_patterns(text)
      check_review_patterns(text)

      {
        compliant: @violations.empty?,
        violations: @violations,
        suggestions: @suggestions
      }
    end

    # Check if text is compliant (convenience method)
    #
    # @param text [String] The text to check
    # @return [Boolean] true if compliant
    #
    def compliant?(text)
      check(text)[:compliant]
    end

    private

    def check_prohibited_patterns(text)
      PROHIBITED_PATTERNS.each do |category, patterns|
        patterns.each do |pattern|
          if (match = text.match(pattern))
            @violations << {
              pattern: pattern.source,
              match: match[0],
              category: category.to_s,
              severity: "high"
            }
          end
        end
      end
    end

    def check_review_patterns(text)
      REVIEW_SUGGESTED.each do |pattern|
        if (match = text.match(pattern))
          @suggestions << {
            pattern: pattern.source,
            match: match[0],
            note: "Review for context - may be fine but warrants verification"
          }
        end
      end
    end

    def compliant_result
      {
        compliant: true,
        violations: [],
        suggestions: []
      }
    end
  end
end
