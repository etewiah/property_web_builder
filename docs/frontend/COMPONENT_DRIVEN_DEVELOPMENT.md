# Component-Driven Development Guide

This guide covers setting up component preview and documentation tools for PropertyWebBuilder's frontend.

| Pipeline | Tool | Purpose |
|----------|------|---------|
| Astro (A-themes) | [Storybook](https://storybook.js.org/) | Component preview, testing, docs |
| Rails (B-themes) | [Lookbook](https://lookbook.build/) | Partial preview, testing, docs |

---

## Part 1: Storybook for Astro Client

### Installation

```bash
cd pwb-frontend-clients/pwb-astrojs-client

# Initialize Storybook with Astro support
npx storybook@latest init --type react

# Install Astro addon (for .astro component support)
npm install -D @storybook/addon-styling
```

### Configuration

#### `.storybook/main.ts`

```typescript
import type { StorybookConfig } from '@storybook/react-vite';

const config: StorybookConfig = {
  stories: [
    '../src/**/*.mdx',
    '../src/**/*.stories.@(js|jsx|mjs|ts|tsx)',
  ],
  addons: [
    '@storybook/addon-links',
    '@storybook/addon-essentials',
    '@storybook/addon-interactions',
  ],
  framework: {
    name: '@storybook/react-vite',
    options: {},
  },
  viteFinal: async (config) => {
    // Import global styles
    return config;
  },
};

export default config;
```

#### `.storybook/preview.ts`

```typescript
import type { Preview } from '@storybook/react';
import '../src/styles/global.css';
import '../src/styles/tokens.css';

const preview: Preview = {
  parameters: {
    backgrounds: {
      default: 'light',
      values: [
        { name: 'light', value: '#ffffff' },
        { name: 'dark', value: '#1a1a2e' },
        { name: 'muted', value: '#f8f9fa' },
      ],
    },
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
  },
  decorators: [
    (Story) => (
      <div style={{ 
        '--pwb-primary-color': '#3b82f6',
        '--pwb-secondary-color': '#64748b',
        '--pwb-accent-color': '#f59e0b',
      } as React.CSSProperties}>
        <Story />
      </div>
    ),
  ],
};

export default preview;
```

### Creating Stories

#### Property Card Story

```typescript
// src/stories/PropertyCard.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';

// For React components
import { FavoriteButton } from '../components/react/FavoriteButton';

const meta = {
  title: 'Components/FavoriteButton',
  component: FavoriteButton,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    propertyId: { control: 'number' },
    initialFavorite: { control: 'boolean' },
  },
} satisfies Meta<typeof FavoriteButton>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    propertyId: 1,
    initialFavorite: false,
  },
};

export const Favorited: Story = {
  args: {
    propertyId: 1,
    initialFavorite: true,
  },
};
```

#### Theme Decorator for Palette Testing

```typescript
// src/stories/decorators/ThemeDecorator.tsx
import React from 'react';

const palettes = {
  default: {
    '--pwb-primary-color': '#3b82f6',
    '--pwb-secondary-color': '#64748b',
  },
  ocean: {
    '--pwb-primary-color': '#0891b2',
    '--pwb-secondary-color': '#0e7490',
  },
  sunset: {
    '--pwb-primary-color': '#f97316',
    '--pwb-secondary-color': '#ea580c',
  },
};

export const withTheme = (palette: keyof typeof palettes) => (Story: any) => (
  <div style={palettes[palette] as React.CSSProperties}>
    <Story />
  </div>
);
```

### Running Storybook

```bash
# Development
npm run storybook

# Build static site
npm run build-storybook

# Output: storybook-static/
```

### Directory Structure

```
pwb-frontend-clients/pwb-astrojs-client/
├── .storybook/
│   ├── main.ts
│   └── preview.ts
├── src/
│   ├── components/
│   │   ├── react/
│   │   │   └── FavoriteButton.tsx
│   │   └── astro/
│   │       └── PropertyCard.astro
│   └── stories/
│       ├── FavoriteButton.stories.tsx
│       ├── Button.stories.tsx
│       └── decorators/
│           └── ThemeDecorator.tsx
└── package.json
```

---

## Part 2: Lookbook for Rails

### Installation

```ruby
# Gemfile
group :development do
  gem "lookbook", ">= 2.0"
  gem "view_component" # Optional but recommended
end
```

```bash
bundle install
```

### Configuration

#### `config/application.rb`

```ruby
# Enable Lookbook in development
config.view_component.preview_paths << Rails.root.join("spec/components/previews")
```

#### `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Mount Lookbook in development only
  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
  
  # ... rest of routes
end
```

### Creating Previews

#### Atom: Button Preview

```ruby
# spec/components/previews/atoms/button_preview.rb
class Atoms::ButtonPreview < Lookbook::Preview
  # @!group Variants
  
  # Primary button style
  def primary
    render_button(variant: :primary, text: "Primary Button")
  end
  
  # Secondary button style
  def secondary
    render_button(variant: :secondary, text: "Secondary Button")
  end
  
  # Outline button style
  def outline
    render_button(variant: :outline, text: "Outline Button")
  end
  
  # @!endgroup
  
  # @!group Sizes
  
  def small
    render_button(variant: :primary, size: :sm, text: "Small")
  end
  
  def medium
    render_button(variant: :primary, size: :md, text: "Medium")
  end
  
  def large
    render_button(variant: :primary, size: :lg, text: "Large")
  end
  
  # @!endgroup
  
  # Interactive playground
  # @param text text
  # @param variant select { choices: [primary, secondary, outline, ghost] }
  # @param size select { choices: [sm, md, lg] }
  # @param disabled toggle
  def playground(text: "Click me", variant: :primary, size: :md, disabled: false)
    render_button(text: text, variant: variant.to_sym, size: size.to_sym, disabled: disabled)
  end
  
  private
  
  def render_button(**args)
    render partial: "shared/atoms/button", locals: args
  end
end
```

#### Molecule: Price Display Preview

```ruby
# spec/components/previews/molecules/price_display_preview.rb
class Molecules::PriceDisplayPreview < Lookbook::Preview
  # Sale price display
  def sale
    render partial: "shared/molecules/price_display", locals: {
      formatted_price: "€500,000",
      rental: false
    }
  end
  
  # Rental price display (shows /month suffix)
  def rental
    render partial: "shared/molecules/price_display", locals: {
      formatted_price: "€1,500",
      rental: true
    }
  end
  
  # @param price text
  # @param rental toggle
  def playground(price: "€250,000", rental: false)
    render partial: "shared/molecules/price_display", locals: {
      formatted_price: price,
      rental: rental
    }
  end
end
```

#### Organism: Property Card Preview

```ruby
# spec/components/previews/organisms/property_card_preview.rb
class Organisms::PropertyCardPreview < Lookbook::Preview
  # Standard property card
  def default
    render partial: "shared/organisms/property_card", locals: {
      property: mock_property
    }
  end
  
  # Featured/highlighted property
  def featured
    render partial: "shared/organisms/property_card", locals: {
      property: mock_property(highlighted: true)
    }
  end
  
  # Rental property
  def rental
    render partial: "shared/organisms/property_card", locals: {
      property: mock_property(for_rent: true, for_sale: false)
    }
  end
  
  # @param title text
  # @param price text
  # @param bedrooms number
  # @param bathrooms number
  # @param highlighted toggle
  # @param for_rent toggle
  def playground(
    title: "Modern Apartment",
    price: "€350,000",
    bedrooms: 3,
    bathrooms: 2,
    highlighted: false,
    for_rent: false
  )
    render partial: "shared/organisms/property_card", locals: {
      property: mock_property(
        title: title,
        formatted_price: price,
        count_bedrooms: bedrooms,
        count_bathrooms: bathrooms,
        highlighted: highlighted,
        for_rent: for_rent
      )
    }
  end
  
  private
  
  def mock_property(**overrides)
    defaults = {
      id: 1,
      title: "Luxury Villa with Pool",
      slug: "luxury-villa",
      formatted_price: "€500,000",
      count_bedrooms: 4,
      count_bathrooms: 3,
      count_garages: 2,
      highlighted: false,
      for_sale: true,
      for_rent: false,
      primary_photo_url: "https://via.placeholder.com/640x360"
    }
    
    OpenStruct.new(defaults.merge(overrides)).tap do |p|
      p.define_singleton_method(:highlighted?) { p.highlighted }
      p.define_singleton_method(:for_sale?) { p.for_sale }
      p.define_singleton_method(:for_rent?) { p.for_rent }
    end
  end
end
```

### Theme Switching in Lookbook

```ruby
# spec/components/previews/preview_helper.rb
module PreviewHelper
  PALETTES = {
    default: {
      "pwb-primary-color" => "#3b82f6",
      "pwb-secondary-color" => "#64748b"
    },
    ocean: {
      "pwb-primary-color" => "#0891b2",
      "pwb-secondary-color" => "#0e7490"
    },
    sunset: {
      "pwb-primary-color" => "#f97316",
      "pwb-secondary-color" => "#ea580c"
    }
  }
  
  def with_palette(palette_name, &block)
    vars = PALETTES[palette_name.to_sym] || PALETTES[:default]
    style = vars.map { |k, v| "--#{k}: #{v}" }.join("; ")
    
    content_tag(:div, style: style, &block)
  end
end
```

### Running Lookbook

```bash
# Start Rails server
rails server

# Visit Lookbook
open http://localhost:3000/lookbook
```

### Directory Structure

```
app/views/shared/
├── atoms/
│   ├── _button.html.erb
│   ├── _badge.html.erb
│   └── _icon.html.erb
├── molecules/
│   ├── _price_display.html.erb
│   └── _property_stats.html.erb
└── organisms/
    └── _property_card.html.erb

spec/components/previews/
├── atoms/
│   ├── button_preview.rb
│   └── badge_preview.rb
├── molecules/
│   ├── price_display_preview.rb
│   └── property_stats_preview.rb
├── organisms/
│   └── property_card_preview.rb
└── preview_helper.rb
```

---

## Part 3: Integration with CI/CD

### Visual Regression Testing (Chromatic)

For Storybook, add visual regression testing:

```bash
# Install Chromatic
npm install -D chromatic

# Run visual tests
npx chromatic --project-token=<your-token>
```

### Lookbook Static Export

```bash
# Generate static preview site
rails lookbook:preview:build

# Output: public/lookbook/
```

---

## Part 4: Documentation Generation

### Storybook Docs

Enable MDX documentation:

```mdx
{/* src/stories/PropertyCard.mdx */}
import { Meta, Story, Canvas, ArgsTable } from '@storybook/blocks';
import * as PropertyCardStories from './PropertyCard.stories';

<Meta of={PropertyCardStories} />

# Property Card

The property card displays a summary of a property listing.

## Usage

```jsx
<PropertyCard property={propertyData} />
```

## Examples

<Canvas of={PropertyCardStories.Default} />

<Canvas of={PropertyCardStories.Featured} />

## Props

<ArgsTable of={PropertyCardStories} />
```

### Lookbook Documentation

```ruby
# Add YARD-style documentation
class Atoms::ButtonPreview < Lookbook::Preview
  # @label Primary Button
  # @notes
  #   The primary button is used for main call-to-action elements.
  #   
  #   ## Usage
  #   
  #   ```erb
  #   <%= render "shared/atoms/button", text: "Submit", variant: :primary %>
  #   ```
  #   
  #   ## Accessibility
  #   - Always include descriptive text
  #   - Use disabled state appropriately
  def primary
    render_button(variant: :primary, text: "Primary Button")
  end
end
```

---

## Implementation Checklist

### Astro (Storybook)

- [ ] Install Storybook with `npx storybook@latest init`
- [ ] Configure `.storybook/main.ts` and `preview.ts`
- [ ] Import global CSS and tokens
- [ ] Create stories for React components (`FavoriteButton`, `ViewToggle`)
- [ ] Add theme decorator for palette testing
- [ ] Set up Chromatic for visual regression (optional)

### Rails (Lookbook)

- [ ] Add `lookbook` gem to Gemfile
- [ ] Mount Lookbook route in development
- [ ] Create previews for atoms (button, badge, icon)
- [ ] Create previews for molecules (price_display, property_stats)
- [ ] Create previews for organisms (property_card)
- [ ] Add theme switching helpers

---

## Related Documents

- [Atomic Design Plan](./ATOMIC_DESIGN_PLAN.md) - Component structure
- [Design Tokens](./DESIGN_TOKENS.md) - CSS variables for theming
- [Frontend Standards](../FRONTEND_STANDARDS.md) - Naming conventions
