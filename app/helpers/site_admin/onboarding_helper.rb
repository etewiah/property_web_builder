# frozen_string_literal: true

module SiteAdmin
  module OnboardingHelper
    THEME_GRADIENTS = [
      'from-blue-400 to-blue-600',
      'from-green-400 to-teal-500',
      'from-purple-400 to-indigo-500',
      'from-orange-400 to-red-500',
      'from-pink-400 to-rose-500',
      'from-gray-400 to-gray-600'
    ].freeze

    THEME_DESCRIPTIONS = {
      'flavor' => 'Clean and modern design',
      'flavor-starter' => 'Simple starter template',
      'flavor-starter-header' => 'Prominent header layout',
      'flavor-starter-with-hero' => 'Full-width hero section',
      'flavor-starter-nav' => 'Enhanced navigation',
      'flavor-starter-nav2' => 'Alternative navigation style'
    }.freeze

    def theme_gradient_class(index)
      THEME_GRADIENTS[index % THEME_GRADIENTS.length]
    end

    def theme_description(theme)
      THEME_DESCRIPTIONS[theme] || 'Professional real estate theme'
    end
  end
end
