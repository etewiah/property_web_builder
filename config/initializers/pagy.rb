# frozen_string_literal: true

# Pagy Configuration
# See https://ddnexus.github.io/pagy/docs/extras/

require 'pagy/extras/overflow'

# Default items per page
Pagy::DEFAULT[:limit] = 25

# Overflow handling: empty_page returns empty results for out-of-bounds pages
Pagy::DEFAULT[:overflow] = :empty_page
