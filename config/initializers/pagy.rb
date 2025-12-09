# frozen_string_literal: true

# Pagy 43.x Configuration
# See https://ddnexus.github.io/pagy/

# Default items per page
Pagy.options[:limit] = 25

# Overflow handling: empty_page returns empty results for out-of-bounds pages
Pagy.options[:overflow] = :empty_page
