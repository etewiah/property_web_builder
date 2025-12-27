# About-Us Page Seed Data Analysis

Generated: 2025-12-27

## Overview

The PropertyWebBuilder codebase contains about-us page seed data structured as YAML files within seed packs. The about-us content is organized using a flexible content system that supports multi-language translations and team member information with associated images.

## Files Containing About-Us Seed Data

### Seed Pack Content Files

1. **Netherlands Urban Pack**
   - Path: `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/netherlands_urban/content/about-us.yml`
   - Size: 4.8K
   - Languages: Dutch (nl), English (en)

2. **Spain Luxury Pack**
   - Path: `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/spain_luxury/content/about-us.yml`
   - Size: 3.8K
   - Languages: Spanish (es), English (en), German (de)

## About-Us Content Structure

### Content HTML Section

The main about-us content is stored under the `content_html` key with nested `main_content` containing multi-language HTML content:

```yaml
content_html:
  main_content:
    nl: "<h2>Over Van der Berg Makelaars</h2>..."
    en: "<h2>About Van der Berg Real Estate</h2>..."
    es: "<h2>Sobre Costa Luxury Properties</h2>..."
    de: "<h2>Über Costa Luxury Properties</h2>..."
```

**Features:**
- Full HTML support (h2, h3, p, ul, li, strong tags)
- Multi-language support (2-3 languages per pack)
- Contains company history, values, and mission statements
- Values are typically presented in lists (Reliability, Expertise, Personal approach, Results-oriented)

### Team Grid Section

The team information is stored under `teams/team_grid` with the following structure:

```yaml
teams/team_grid:
  section_title:
    nl: "Maak kennis met ons team"
    en: "Meet Our Team"
  section_subtitle:
    nl: "Ervaren professionals met passie voor vastgoed"
    en: "Experienced professionals with a passion for real estate"
  member_1_name: "Willem van der Berg"
  member_1_role:
    nl: "Directeur / Register Makelaar"
    en: "Director / Licensed Agent"
  member_1_bio:
    nl: "Willem richtte Van der Berg Makelaars op in 1998..."
    en: "Willem founded Van der Berg Real Estate in 1998..."
  member_1_email: "willem@vanderbergmakelaars.nl"
  member_1_image: "db/seeds/packs/netherlands_urban/images/team_director.jpg"
  # ... member_2, member_3, member_4 follow same pattern
```

**Features:**
- Up to 4 team members per pack (currently)
- Each member has: name, role (multilingual), bio (multilingual), email, image path
- Section title and subtitle are multilingual

## Images Used for About-Us Content

### Team Member Images (Netherlands Urban Pack)

Located in: `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/netherlands_urban/images/`

#### Standard Images:
- `team_director.jpg` / `team_director.webp` - Director/main profile
- `team_agent_female.jpg` / `team_agent_female.webp` - Female agent profile
- `team_agent_male.jpg` / `team_agent_male.webp` - Male agent profile
- `team_assistant.jpg` / `team_assistant.webp` - Assistant/support staff

#### Mobile-optimized Images:
- `team_director_mobile.jpg` / `team_director_mobile.webp`
- `team_agent_female_mobile.jpg` / `team_agent_female_mobile.webp`
- `team_agent_male_mobile.jpg` / `team_agent_male_mobile.webp`
- `team_assistant_mobile.jpg` / `team_assistant_mobile.webp`

**Note:** The Spain Luxury pack references the same team images from the Netherlands Urban pack (reusing paths), indicating image pooling across packs.

### Image Path Format

Images are referenced using the following path format in YAML:
```
member_1_image: "db/seeds/packs/netherlands_urban/images/team_director.jpg"
```

This is a relative path that is processed during seeding to either:
1. Upload to local storage (fallback mode)
2. Create external URLs pointing to R2 CDN (preferred mode with SEED_IMAGES_BASE_URL or R2_SEED_IMAGES_BUCKET)

## Data Model Structure

### Content Model (`Pwb::Content`)

The content seed data is loaded into the `Pwb::Content` model:

```ruby
# Table: pwb_contents
- id (primary key)
- key (unique, scoped to website) - e.g., "content_html", "teams/team_grid"
- website_id (multi-tenancy)
- translations (jsonb) - stores all locale translations
- status, tag, input_type, sort_order (metadata)
- created_at, updated_at
- last_updated_by_user_id
```

**Relationships:**
- `belongs_to :website` - Each content is scoped to a website (tenant)
- `has_many :content_photos` - Can have associated photos via ContentPhoto model

### ContentPhoto Model (`Pwb::ContentPhoto`)

```ruby
# Table: pwb_content_photos
- id (primary key)
- content_id (foreign key)
- image (ActiveStorage attachment)
- external_url (string) - for external CDN URLs
- description, folder, block_key (metadata)
- sort_order, file_size
- created_at, updated_at
```

**Features:**
- Supports both local file uploads (ActiveStorage) and external URLs
- Automatically generates optimized image variants (800x600)
- Can extract filenames from external URLs
- Exposes `optimized_image_url` method for consistent image serving

## How Content is Currently NOT Used

The theme partials show the about-us section is **commented out** in both default and Brisbane themes:

- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/default/views/pwb/welcome/_about_us.html.erb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/brisbane/views/pwb/welcome/_about_us.html.erb`

Both files contain identical commented-out code that would render `@about_us.raw` content.

## Seeding Infrastructure

### Seed Pack System (`Pwb::SeedPack`)

The seed pack system handles loading content from YAML files:

```ruby
# Location: /Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/seed_pack.rb

def seed_pack_content(content_dir)
  Dir.glob(content_dir.join('*.yml')).each do |content_file|
    content_data = YAML.safe_load(File.read(content_file), symbolize_names: true)
    
    content_data.each do |key, translations|
      content = @website.contents.find_or_initialize_by(key: key.to_s)
      translations.each do |locale, value|
        content.send("raw_#{locale}=", value) if content.respond_to?("raw_#{locale}=")
      end
      content.save!
    end
  end
end
```

### Process Flow

1. **Pack Discovery**: Seed pack YAML files are located in `db/seeds/packs/{pack_name}/content/`
2. **Content Loading**: `Pwb::SeedPack.apply!(website:)` loads content files via `seed_pack_content()`
3. **Data Transformation**: YAML keys become `Content#key` values, nested locales become `Content#raw_xx` attributes
4. **Multi-tenancy**: Each website gets its own scoped Content records via `website_id`
5. **Image Handling**: Image paths in YAML are currently referenced but not automatically processed into ContentPhoto records

## Usage Notes

### Multi-language Support

- Languages are identified by 2-letter locale codes (nl, en, es, de, etc.)
- Content uses Mobility gem for translations
- Both content_html and team member fields support per-locale translations
- Supported locales are defined in Rails' `I18n.available_locales`

### Image URL Generation

When seed images are configured with R2 or external storage:
- File paths like `db/seeds/packs/netherlands_urban/images/team_director.jpg` are mapped to R2 keys
- Pattern: `packs/{pack_name}/{filename}` → `https://cdn.example.com/packs/netherlands_urban/team_director.jpg`
- External URLs bypass local storage, reducing bloat

### Limitations

1. **No Direct Image Association**: Team member images in YAML are stored as paths/URLs but are NOT automatically created as ContentPhoto records
2. **Manual Image Management**: Images must be managed separately from content seeding
3. **No Validation**: The seeding process doesn't validate that image files exist at referenced paths

## Key Findings Summary

| Aspect | Details |
|--------|---------|
| **Number of About-Us Packs** | 2 (netherlands_urban, spain_luxury) |
| **Languages per Pack** | 2-3 (nl, en, es, de) |
| **Team Members per Pack** | 4 members |
| **Total Image Assets** | 20 files (8 base images with .jpg and .webp variants, plus 4 mobile variants) |
| **Content Structure** | YAML with nested translations and image references |
| **Data Model** | Pwb::Content with optional Pwb::ContentPhoto association |
| **Current Usage** | Seed data exists but theme rendering is commented out |
| **Storage Mode** | Supports both local uploads and external CDN URLs |

## Related Files

**Seeding Infrastructure:**
- `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/seed_pack.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/contents_seeder.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds.rb`

**Models:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/content.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/content_photo.rb`

**Factories:**
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/factories/pwb_contents.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/factories/pwb_content_photos.rb`

**Theme Views:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/default/views/pwb/welcome/_about_us.html.erb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/brisbane/views/pwb/welcome/_about_us.html.erb`
