# PropertyWebBuilder Theme System Documentation

This directory contains comprehensive documentation for the PropertyWebBuilder theme and color palette system.

## Quick Links

| Document | Description |
|----------|-------------|
| [Quick Start Guide](QUICK_START_GUIDE.md) | Get started with theming in 5 minutes |
| [Theme Quick Reference](THEME_QUICK_REFERENCE.md) | One-page reference for common tasks |
| [Theme System Quick Reference](THEME_SYSTEM_QUICK_REFERENCE.md) | Architecture overview at a glance |

## Core Documentation

### Architecture

| Document | Description |
|----------|-------------|
| [Theme and Color System](THEME_AND_COLOR_SYSTEM.md) | **Start here** - Complete architecture overview |
| [Recommended Architecture](RECOMMENDED_ARCHITECTURE.md) | Best practices and patterns |
| [Implementation Patterns](THEME_IMPLEMENTATION_PATTERNS.md) | Code patterns for theme development |

### Color Palettes

| Document | Description |
|----------|-------------|
| [Color Palettes Architecture](color-palettes/COLOR_PALETTES_ARCHITECTURE.md) | How palettes are loaded and applied |
| [Theme Palette System](color-palettes/THEME_PALETTE_SYSTEM.md) | Palette structure and validation |
| [Dynamic Color Palette Proposal](color-palettes/DYNAMIC_COLOR_PALETTE_PROPOSAL.md) | Future dynamic palette features |

### Creating Themes

| Document | Description |
|----------|-------------|
| [Theme Creation Checklist](THEME_CREATION_CHECKLIST.md) | Step-by-step theme creation guide |
| [Semantic CSS Classes](SEMANTIC_CSS_CLASSES.md) | PWB CSS class naming conventions |
| [Tailwind Helpers](TAILWIND_HELPERS.md) | Tailwind CSS integration guide |

### Accessibility

| Document | Description |
|----------|-------------|
| [Biarritz Contrast Guide](BIARRITZ_CONTRAST_GUIDE.md) | WCAG AA compliance reference |

### Reference

| Document | Description |
|----------|-------------|
| [Theming System (Legacy)](11_Theming_System.md) | Original theming documentation |
| [README Theme System](README_THEME_SYSTEM.md) | Additional theme system info |
| [Theming System Audit](THEMING_SYSTEM_AUDIT.md) | System health and status |
| [Implementation Roadmap](IMPLEMENTATION_ROADMAP.md) | Future improvements |
| [Refactor Recommendations](REFACTOR_RECOMMENDATIONS_FOR_THEMING.md) | Technical debt and improvements |
| [Troubleshooting](TROUBLESHOOTING.md) | Common issues and solutions |

## System Overview

### Current Architecture (January 2025)

```
Themes                    Palettes                   Website
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ default          │────▶│ classic_red      │     │ theme_name       │
│ brisbane         │     │ ocean_blue       │◀────│ selected_palette │
│ bologna          │     │ forest_green     │     │ style_variables  │
│ barcelona (off)  │     │ sunset_orange    │     │ dark_mode_setting│
│ biarritz (off)   │     │ + 12 more...     │     └──────────────────┘
└──────────────────┘     └──────────────────┘              │
         │                        │                        │
         └────────────────────────┴────────────────────────┘
                                  │
                                  ▼
                    ┌──────────────────────────┐
                    │   CSS Custom Properties   │
                    │   --pwb-primary           │
                    │   --pwb-secondary         │
                    │   --pwb-accent            │
                    │   + typography, spacing   │
                    └──────────────────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Theme Registry | `app/themes/config.json` | Theme definitions and metadata |
| Theme Model | `app/models/pwb/theme.rb` | Theme loading and inheritance |
| Palette Loader | `app/services/pwb/palette_loader.rb` | Load palettes from JSON files |
| Palette Validator | `app/services/pwb/palette_validator.rb` | Validate palette structure |
| Color Utils | `app/services/pwb/color_utils.rb` | WCAG contrast, shade generation |
| Palette Compiler | `app/services/pwb/palette_compiler.rb` | Compile CSS for production |
| Website Styleable | `app/models/concerns/pwb/website_styleable.rb` | Per-website style management |
| CSS Templates | `app/views/pwb/custom_css/_*.css.erb` | Dynamic CSS generation |

### Enabled Themes

| Theme | Palettes | Description |
|-------|----------|-------------|
| **default** | 6 palettes | Base Tailwind/Flowbite theme |
| **brisbane** | 6 palettes | Luxury real estate (gold/navy) |
| **bologna** | 4 palettes | Traditional European style |

### Disabled Themes

| Theme | Reason |
|-------|--------|
| barcelona | Incomplete implementation |
| biarritz | Needs accessibility fixes |

## Claude Code Skills

Two Claude Code skills are available for theme work:

### theme-creation
Use when creating new themes, adding palettes, or modifying theme templates.

```
Invoke with: /skill theme-creation
```

### theme-evaluation
Use when auditing themes for WCAG compliance, checking contrast ratios, or identifying visual issues.

```
Invoke with: /skill theme-evaluation
```

## Common Tasks

### Apply a Palette to a Website

```ruby
website = Pwb::Website.find_by(subdomain: 'mysite')
website.apply_palette!('ocean_blue')
```

### Check WCAG Contrast

```ruby
Pwb::ColorUtils.wcag_aa_compliant?('#ffffff', '#333333')
# => true (14.0:1 ratio)

Pwb::ColorUtils.contrast_ratio('#ffffff', '#9ca3af')
# => 2.9 (fails AA - needs 4.5:1)
```

### Validate a Palette

```ruby
validator = Pwb::PaletteValidator.new
result = validator.validate(palette_hash)
result.valid?   # => true/false
result.errors   # => ["Missing required color: primary_color"]
```

### Generate Dark Mode Colors

```ruby
light_colors = { primary_color: '#3498db', background_color: '#ffffff' }
dark_colors = Pwb::ColorUtils.generate_dark_mode_colors(light_colors)
```

## File Locations

```
app/
├── themes/
│   ├── config.json                    # Theme registry
│   ├── shared/
│   │   └── color_schema.json          # Palette JSON schema
│   ├── default/
│   │   ├── palettes/*.json            # 6 palette files
│   │   └── views/                     # Theme templates
│   ├── brisbane/
│   │   ├── palettes/*.json            # 6 palette files
│   │   └── views/                     # Theme templates
│   └── bologna/
│       ├── palettes/*.json            # 4 palette files
│       └── views/                     # Theme templates
├── models/
│   ├── pwb/theme.rb                   # Theme model
│   └── concerns/pwb/website_styleable.rb
├── services/pwb/
│   ├── palette_loader.rb
│   ├── palette_validator.rb
│   ├── palette_compiler.rb
│   └── color_utils.rb
├── views/pwb/custom_css/
│   ├── _base_variables.css.erb        # Core CSS variables
│   ├── _default.css.erb               # Default theme CSS
│   ├── _brisbane.css.erb              # Brisbane theme CSS
│   └── _bologna.css.erb               # Bologna theme CSS
└── assets/
    ├── stylesheets/
    │   ├── tailwind-input.css         # Default Tailwind input
    │   ├── tailwind-brisbane.css      # Brisbane Tailwind input
    │   └── tailwind-bologna.css       # Bologna Tailwind input
    └── builds/
        ├── tailwind-default.css       # Compiled Tailwind
        ├── tailwind-brisbane.css
        └── tailwind-bologna.css
```

## Test Coverage

Theme system has comprehensive test coverage:

```
spec/services/pwb/
├── palette_loader_spec.rb      # 20 tests
├── palette_validator_spec.rb   # 15+ tests
├── color_utils_spec.rb         # 26 tests
└── palette_compiler_spec.rb    # 28 tests

spec/models/pwb/
├── theme_spec.rb
└── website_styleable_spec.rb

spec/helpers/pwb/
└── page_parts_color_system_spec.rb  # 10 tests
```

Run theme-related tests:
```bash
bundle exec rspec spec/services/pwb/palette*.rb spec/services/pwb/color_utils_spec.rb
```

---

**Last Updated:** January 2025
