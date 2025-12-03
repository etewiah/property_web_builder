# PropertyWebBuilder Refactoring Recommendations

This document outlines a strategic plan to improve the developer experience (DX), maintainability, and robustness of the PropertyWebBuilder theme and page part system.

## 1. Move Liquid Templates from Database to File System

**Current State:**
Liquid templates are stored as strings within the `template` column of the `pwb_page_parts` table and seeded via YAML files in `db/yml_seeds/page_parts/`.

**Problems:**
- **Poor DX:** No syntax highlighting, linting, or auto-completion for Liquid/HTML.
- **Workflow Friction:** Changes require editing a YAML string and running a Rake task (`pwb:db:update_page_parts`).
- **Version Control:** Git diffs on large one-line strings in YAML are unreadable.

**Implementation Plan:**

### Step 1: Create Template Directory
Create a dedicated directory for page part templates:
```bash
mkdir -p app/views/pwb/page_parts
```

### Step 2: Database Migration
Add a column to reference the file path (optional, or just use convention over configuration based on `page_part_key`).
```ruby
# db/migrate/xxxx_add_template_path_to_page_parts.rb
add_column :pwb_page_parts, :template_path, :string
```

### Step 3: Update `Pwb::PagePart` Model
Modify the model to prefer reading from the file system in development.

```ruby
# app/models/pwb/page_part.rb
def template_content
  # Convention: app/views/pwb/page_parts/{page_part_key}.liquid
  file_path = Rails.root.join("app/views/pwb/page_parts/#{page_part_key}.liquid")
  
  if File.exist?(file_path)
    File.read(file_path)
  else
    # Fallback to database for legacy support
    self[:template]
  end
end
```

### Step 4: Migrate Existing Seeds
Extract the HTML from `db/yml_seeds/page_parts/*.yml` into individual `.liquid` files.

**Example:**
*From `db/yml_seeds/page_parts/home__landing_hero.yml`:*
```yaml
template: >
  <div class="hero-section">...</div>
```

*To `app/views/pwb/page_parts/landing_hero.liquid`:*
```html
<div class="hero-section">
  ...
</div>
```

---

## 2. Decouple Editor Configuration (Ruby DSL)

**Current State:**
The configuration for the admin editor (fields, labels, types) is stored as a JSON object inside the `editor_setup` column in the database.

**Problems:**
- **Duplication:** Field names in `editor_setup` must manually match variables in the Liquid template.
- **Fragility:** JSON in YAML is error-prone to edit.

**Implementation Plan:**

### Step 1: Create Definition DSL
Create a Ruby class to define page parts programmatically.

```ruby
# app/lib/pwb/page_part_definition.rb
module Pwb
  class PagePartDefinition
    attr_reader :key, :fields

    def self.define(key, &block)
      definition = new(key)
      definition.instance_eval(&block)
      Pwb::PagePartRegistry.register(definition)
    end

    def field(name, type:, label: nil)
      @fields << { name: name, type: type, label: label || name.to_s.humanize }
    end
    
    # ... initialization logic
  end
end
```

### Step 2: Define Parts
Create definitions in an initializer or dedicated directory.

```ruby
# config/initializers/page_parts.rb
Pwb::PagePartDefinition.define :landing_hero do
  field :landing_title_a, type: :single_line_text, label: "Title"
  field :landing_content_a, type: :html, label: "Description"
  field :landing_img, type: :image, label: "Background Image"
end
```

### Step 3: Update Admin API
Modify the controller that serves the editor configuration to read from `Pwb::PagePartRegistry` instead of the `pwb_page_parts.editor_setup` column.

---

## 3. Enforce Semantic HTML + Theme CSS Pattern

**Current State:**
Templates often contain framework-specific utility classes (e.g., Bootstrap `col-md-4` or Tailwind `text-4xl`), making it hard to switch themes without rewriting content structure.

**Implementation Plan:**

### Step 1: Define Standard Component Classes
Create a documentation standard for class names that all themes must support.
- `.pwb-hero`
- `.pwb-card`
- `.pwb-grid`
- `.pwb-btn-primary`

### Step 2: Linting Task
Create a Rake task to scan Liquid files for forbidden patterns (e.g., Tailwind utility classes).

```ruby
# lib/tasks/pwb_lint.rake
task :lint_templates do
  forbidden_patterns = [/text-\d+xl/, /p-\d+/, /bg-[a-z]+-\d+/]
  
  Dir.glob("app/views/pwb/page_parts/*.liquid").each do |file|
    content = File.read(file)
    forbidden_patterns.each do |pattern|
      if content.match?(pattern)
        puts "Warning: Utility class found in #{file}: #{pattern}"
      end
    end
  end
end
```

---

## 4. Componentize UI Elements (Liquid Partials)

**Current State:**
Common UI elements (buttons, cards) are copy-pasted across different page parts.

**Implementation Plan:**

### Step 1: Configure Liquid FileSystem
Tell Liquid where to look for partials.

```ruby
# config/initializers/liquid.rb
Liquid::Template.file_system = Liquid::LocalFileSystem.new(Rails.root.join('app/views/pwb/partials'))
```

### Step 2: Create Partials
Create reusable snippets.

**`app/views/pwb/partials/_button.liquid`**
```html
<a href="{{ url }}" class="pwb-btn {{ class }}">
  {{ text }}
</a>
```

### Step 3: Use in Templates
```html
<!-- app/views/pwb/page_parts/landing_hero.liquid -->
<div class="hero-actions">
  {% include 'button', text: 'Contact Us', url: '/contact', class: 'pwb-btn-primary' %}
</div>
```

---

## 5. Editing Workflows & Scenarios

### Scenario A: Super Admin (Developer) - Base Template Editing
**Goal:** Allow technical admins to modify the underlying structure (Liquid templates) and default styles.

**Implementation:**
1.  **File-Based Editing:** Since we are moving templates to the file system (Recommendation #1), Super Admins with server access can edit `.liquid` files directly in `app/views/pwb/page_parts/`.
2.  **Web-Based IDE (Optional):** For Super Admins without shell access, build a "Theme Editor" in the admin panel that reads/writes to these files (or a database override layer if file system is read-only in production).
    *   *Note:* If using a database override layer, the `template_content` method in `PagePart` should check: `Database Override -> File System -> Default`.

### Scenario B: Regular Admin (Tenant) - Content & Style Tweaks
**Goal:** Allow non-technical admins to edit text, images, and basic theme variables (colors, fonts) directly from the page they are viewing.

**Implementation:**

#### 1. The `/edit` Route Pattern
Implement a middleware or controller concern that intercepts requests ending in `/edit`.

*   **Route:** `GET /:locale/*path/edit` (e.g., `/en/home/edit`)
*   **Action:** Renders the page in "Editor Mode".
*   **Authorization:** Checks if `current_user` is an admin.

#### 2. In-Context Editor UI
When in "Editor Mode", inject a JavaScript overlay (React/Vue) that:
*   **Highlights Editable Regions:** Wraps each Page Part in a container with an "Edit" button.
*   **Sidebar Controls:** Clicking "Edit" opens a sidebar with the fields defined in the `PagePartDefinition` (Recommendation #2).
*   **Live Preview:** Updates to fields reflect immediately in the DOM (where possible) or trigger a partial reload.

#### 3. CSS Variable Customization
Allow admins to override specific CSS variables defined in the theme.

*   **Storage:** Add a `style_variables` JSON column to the `Website` or `Theme` model.
*   **Injection:** In the application layout, inject these variables into the `:root` scope.

```html
<!-- app/views/layouts/application.html.erb -->
<style>
  :root {
    --primary-color: <%= @current_website.style_variables['primary_color'] || '#3b82f6' %>;
    --secondary-color: <%= @current_website.style_variables['secondary_color'] || '#1f2937' %>;
  }
</style>
```

*   **Editor Interface:** The `/edit` sidebar should have a "Theme Settings" tab to pick colors.

---

## 6. Theme Development Strategy

The changes above significantly simplify creating **CSS-based themes** (changing colors/fonts via variables). However, to support **Structural Themes** (where the HTML layout differs significantly), we need one additional mechanism: **Theme-Specific Template Lookups**.

### 1. The Lookup Path
Modify the `PagePart` model to look for templates in a theme-specific directory before falling back to the default.

**Updated `template_content` logic:**
1.  **Database Override:** Check if the user has customized the template via the UI.
2.  **Theme Override:** Check `app/themes/[current_theme]/page_parts/[key].liquid`.
3.  **Default:** Check `app/views/pwb/page_parts/[key].liquid`.

```ruby
# app/models/pwb/page_part.rb
def template_content
  theme_name = website.theme_name || 'default'
  
  # 1. Theme Specific File
  theme_path = Rails.root.join("app/themes/#{theme_name}/page_parts/#{page_part_key}.liquid")
  return File.read(theme_path) if File.exist?(theme_path)

  # 2. Default File
  default_path = Rails.root.join("app/views/pwb/page_parts/#{page_part_key}.liquid")
  return File.read(default_path) if File.exist?(default_path)

  # 3. Database Fallback
  self[:template]
end
```

### 2. Creating a New Theme
With this system, adding a new theme becomes a structured process:

#### Step A: Registration
Add the theme metadata to `app/themes/config.json`.
```json
{
  "name": "modern-dark",
  "friendly_name": "Modern Dark",
  "preview_image": "/assets/themes/modern-dark.jpg"
}
```

#### Step B: Base Styling (Required)
Create the CSS file that implements the standard semantic classes (Recommendation #3).
`app/views/pwb/custom_css/_modern-dark.css.erb`

#### Step C: Structural Overrides (Optional)
If the "Modern Dark" theme needs a completely different Hero section HTML structure:
1.  Create `app/themes/modern-dark/page_parts/`
2.  Add `landing_hero.liquid` with the custom HTML.
3.  *Note:* The Liquid variables (e.g., `{{ title }}`) must match the standard definition so the content remains compatible.


