# Blog Feature Architecture for PropertyWebBuilder

## Overview

This document outlines the implementation architecture for adding blogging functionality to PropertyWebBuilder. The design follows existing patterns for multi-tenancy, content management, and API structure.

## Rationale

Blog functionality benefits property websites by:
- **SEO**: Content marketing drives organic traffic
- **Lead generation**: Educational content converts visitors to leads
- **Authority**: Market insights establish agent expertise
- **Engagement**: Fresh content encourages repeat visits

---

## Database Schema

### Core Tables

```
pwb_blog_posts
├── id (PK)
├── website_id (FK → pwb_websites) [tenant scope]
├── author_id (FK → pwb_users)
├── slug (unique per website)
├── status (draft | published | archived)
├── published_at (datetime, for scheduling)
├── featured (boolean)
├── position (integer, manual ordering)
├── view_count (integer, analytics)
├── translations (JSONB - Mobility)
│   ├── title
│   ├── excerpt
│   ├── content (HTML)
│   └── meta_description
├── created_at
├── updated_at
└── last_updated_by_user_id

pwb_blog_categories
├── id (PK)
├── website_id (FK)
├── slug (unique per website)
├── position (integer)
├── translations (JSONB)
│   ├── name
│   └── description
└── timestamps

pwb_blog_post_categories (join table)
├── blog_post_id (FK)
└── blog_category_id (FK)

pwb_blog_tags
├── id (PK)
├── website_id (FK)
├── slug (unique per website)
├── translations (JSONB)
│   └── name
└── timestamps

pwb_blog_post_tags (join table)
├── blog_post_id (FK)
└── blog_tag_id (FK)

pwb_blog_comments (Phase 2)
├── id (PK)
├── website_id (FK)
├── blog_post_id (FK)
├── author_name
├── author_email
├── content
├── approved (boolean)
└── timestamps
```

### Index Strategy

```ruby
add_index :pwb_blog_posts, [:website_id, :slug], unique: true
add_index :pwb_blog_posts, [:website_id, :status]
add_index :pwb_blog_posts, [:website_id, :published_at]
add_index :pwb_blog_posts, [:website_id, :featured]
add_index :pwb_blog_categories, [:website_id, :slug], unique: true
```

---

## Model Architecture

### Dual Namespace Pattern

Following the existing pattern, models exist in two namespaces:

| Namespace | Purpose | Tenant Scoping |
|-----------|---------|----------------|
| `Pwb::BlogPost` | Base model, cross-tenant operations | Manual |
| `PwbTenant::BlogPost` | Tenant-scoped via `acts_as_tenant` | Automatic |

### Base Model (Pwb::BlogPost)

```ruby
# app/models/pwb/blog_post.rb
module Pwb
  class BlogPost < ApplicationRecord
    extend Mobility

    self.table_name = 'pwb_blog_posts'

    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :author, class_name: 'Pwb::User', optional: true

    has_many :blog_post_categories, dependent: :destroy
    has_many :categories, through: :blog_post_categories
    has_many :blog_post_tags, dependent: :destroy
    has_many :tags, through: :blog_post_tags

    translates :title, :excerpt, :content, :meta_description

    scope :published, -> { where(status: 'published').where('published_at <= ?', Time.current) }
    scope :featured, -> { where(featured: true) }
    scope :recent, -> { order(published_at: :desc) }

    validates :title, :slug, :website_id, presence: true
    validates :slug, uniqueness: { scope: :website_id }

    enum :status, { draft: 'draft', published: 'published', archived: 'archived' }
  end
end
```

### Tenant-Scoped Model (PwbTenant::BlogPost)

```ruby
# app/models/pwb_tenant/blog_post.rb
module PwbTenant
  class BlogPost < Pwb::BlogPost
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
```

---

## Controller Architecture

### Admin Controllers

| Controller | Namespace | Purpose |
|------------|-----------|---------|
| `SiteAdmin::BlogPostsController` | site_admin | Web UI CRUD |
| `ApiManage::V1::BlogPostsController` | api_manage | JSON API for admin |

### Public Controllers

| Controller | Namespace | Purpose |
|------------|-----------|---------|
| `ApiPublic::V1::BlogPostsController` | api_public | Public JSON API |
| `Pwb::BlogController` | pwb | Public web pages |

### Route Structure

```ruby
# config/routes.rb

# Admin Web UI
namespace :site_admin do
  resources :blog_posts
  resources :blog_categories
end

# Admin API
namespace :api_manage do
  namespace :v1 do
    scope ':locale' do
      resources :blog_posts do
        member do
          patch :publish
          patch :unpublish
        end
      end
    end
  end
end

# Public API
namespace :api_public do
  namespace :v1 do
    scope ':locale' do
      resources :blog_posts, only: [:index, :show] do
        collection do
          get :featured
          get :by_category
        end
      end
    end
  end
end

# Public pages
scope '/:locale' do
  get 'blog', to: 'pwb/blog#index'
  get 'blog/:slug', to: 'pwb/blog#show'
  get 'blog/category/:slug', to: 'pwb/blog#category'
end
```

---

## Page Part Integration

Blog content displays on pages via the existing Page Part system.

### Page Part Definitions

Add to `PagePartLibrary::DEFINITIONS`:

```ruby
'blog/post_list' => {
  category: :content,
  label: 'Blog Post List',
  fields: {
    section_title: { type: :text, label: 'Title' },
    posts_per_page: { type: :number, default: 10 },
    show_excerpt: { type: :boolean, default: true },
    category_filter: { type: :select, label: 'Category' }
  }
}

'blog/featured_posts' => {
  category: :content,
  label: 'Featured Blog Posts',
  fields: {
    section_title: { type: :text },
    max_posts: { type: :number, default: 3 }
  }
}
```

### Liquid Templates

```liquid
{# app/views/pwb/page_parts/blog/post_list.liquid #}
<section class="pwb-blog-list">
  {% if page_part.section_title.content %}
    <h2>{{ page_part.section_title.content }}</h2>
  {% endif %}

  <div class="pwb-blog-grid">
    {% for post in blog_posts %}
      <article class="pwb-blog-card">
        <h3><a href="/blog/{{ post.slug }}">{{ post.title }}</a></h3>
        {% if page_part.show_excerpt.content %}
          <p>{{ post.excerpt }}</p>
        {% endif %}
        <time>{{ post.published_at | date: "%B %d, %Y" }}</time>
      </article>
    {% endfor %}
  </div>
</section>
```

---

## Multi-Tenancy

### Scoping Rules

| Context | Model to Use | Scoping |
|---------|--------------|---------|
| Site Admin controllers | `PwbTenant::BlogPost` | Automatic via acts_as_tenant |
| API controllers | `current_website.blog_posts` | Explicit via association |
| Public pages | `Pwb::Current.website.blog_posts` | Via Current thread-local |
| Background jobs | `Pwb::BlogPost.where(website_id: ...)` | Explicit where clause |

### Cross-Tenant Operations

Super admin operations use base `Pwb::BlogPost` without tenant scoping:

```ruby
# Cross-tenant analytics (super admin only)
Pwb::BlogPost.group(:website_id).count
```

---

## Translation Support

Using Mobility gem with JSONB backend (existing pattern):

```ruby
# Setting translations
post = Pwb::BlogPost.new
post.title_en = "Market Update"
post.title_es = "Actualización del Mercado"
post.save!

# Reading (uses current locale)
I18n.locale = :es
post.title  # => "Actualización del Mercado"
```

### API Response Format

```json
{
  "post": {
    "id": 1,
    "slug": "market-update",
    "title": "Market Update",
    "title_en": "Market Update",
    "title_es": "Actualización del Mercado",
    "excerpt": "...",
    "status": "published",
    "published_at": "2024-01-31T12:00:00Z"
  }
}
```

---

## File Structure

```
app/
├── models/
│   ├── pwb/
│   │   ├── blog_post.rb
│   │   ├── blog_category.rb
│   │   ├── blog_tag.rb
│   │   ├── blog_post_category.rb
│   │   └── blog_post_tag.rb
│   └── pwb_tenant/
│       ├── blog_post.rb
│       ├── blog_category.rb
│       └── blog_tag.rb
├── controllers/
│   ├── site_admin/
│   │   ├── blog_posts_controller.rb
│   │   └── blog_categories_controller.rb
│   ├── api_manage/v1/
│   │   └── blog_posts_controller.rb
│   ├── api_public/v1/
│   │   └── blog_posts_controller.rb
│   └── pwb/
│       └── blog_controller.rb
├── views/
│   ├── site_admin/blog_posts/
│   │   ├── index.html.erb
│   │   ├── show.html.erb
│   │   ├── new.html.erb
│   │   ├── edit.html.erb
│   │   └── _form.html.erb
│   └── pwb/page_parts/blog/
│       ├── post_list.liquid
│       └── featured_posts.liquid
└── lib/pwb/
    └── blog_search.rb

db/migrate/
├── YYYYMMDDHHMMSS_create_pwb_blog_posts.rb
├── YYYYMMDDHHMMSS_create_pwb_blog_categories.rb
├── YYYYMMDDHHMMSS_create_pwb_blog_tags.rb
└── YYYYMMDDHHMMSS_create_blog_join_tables.rb
```

---

## Implementation Phases

### Phase 1: Core Blog (MVP)

- [ ] Database migrations for posts, categories, tags
- [ ] Base and tenant-scoped models
- [ ] Site Admin CRUD controllers and views
- [ ] API endpoints (manage + public)
- [ ] Basic page parts for listing posts
- [ ] Seed data for development

### Phase 2: Enhanced Features

- [ ] Comments with approval workflow
- [ ] Scheduled publishing
- [ ] Featured posts management
- [ ] Category/tag filtering in admin
- [ ] View count tracking
- [ ] Author profiles

### Phase 3: Advanced

- [ ] Full-text search
- [ ] Related posts algorithm
- [ ] Social sharing integration
- [ ] Email subscriptions
- [ ] Analytics dashboard
- [ ] Rich text editor with media uploads

---

## Configuration

### Website Settings

Add to website's `admin_config` JSON:

```json
{
  "blog_enabled": true,
  "blog_comments_enabled": false,
  "blog_comments_require_approval": true,
  "blog_posts_per_page": 10
}
```

### Feature Toggle

```ruby
# Check if blog is enabled for website
def blog_enabled?
  current_website.admin_config.dig('blog_enabled') == true
end
```

---

## Testing Strategy

### Model Specs

```ruby
# spec/models/pwb/blog_post_spec.rb
RSpec.describe Pwb::BlogPost do
  it { should belong_to(:website) }
  it { should validate_presence_of(:title) }
  it { should validate_uniqueness_of(:slug).scoped_to(:website_id) }

  describe '.published' do
    it 'returns only published posts with past publish date'
  end
end
```

### Controller Specs

```ruby
# spec/controllers/site_admin/blog_posts_controller_spec.rb
RSpec.describe SiteAdmin::BlogPostsController do
  describe 'GET #index' do
    it 'returns posts for current tenant only'
  end
end
```

### Request Specs

```ruby
# spec/requests/api_public/v1/blog_posts_spec.rb
RSpec.describe 'Public Blog API' do
  describe 'GET /api_public/v1/en/blog_posts' do
    it 'returns published posts'
    it 'does not return draft posts'
  end
end
```

---

## Security Considerations

1. **Tenant Isolation**: All queries must be scoped to current website
2. **Authorization**: Admin endpoints require authenticated admin user
3. **Content Sanitization**: HTML content must be sanitized before storage
4. **Rate Limiting**: Public API endpoints should have rate limits
5. **CSRF**: Admin forms must include CSRF tokens

---

## Performance Considerations

1. **Indexes**: Composite indexes on `[website_id, slug]`, `[website_id, status]`
2. **Eager Loading**: Include categories/tags in list queries
3. **Pagination**: Use Kaminari for paginated results
4. **Caching**: Consider fragment caching for post lists
5. **View Counts**: Use `increment!` or async updates to avoid locks

---

## Dependencies

No new gems required. Uses existing:
- `mobility` - Translations
- `acts_as_tenant` - Multi-tenancy
- `kaminari` - Pagination
- `liquid` - Template rendering
