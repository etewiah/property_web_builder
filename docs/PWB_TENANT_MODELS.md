# PwbTenant Scoped Models

The `PwbTenant` namespace provides secure, tenant-scoped access to models that belong to a website.

## Overview

Instead of manually adding `.where(website_id: current_website.id)` to every query, you can use `PwbTenant` models. These models automatically:
1.  **Scope queries** to the current website (via `Pwb::Current.website`).
2.  **Assign website_id** when creating new records.
3.  **Inherit behavior** from the original `Pwb` models (including translations).

## Available Models

*   `PwbTenant::Prop` (inherits from `Pwb::Prop`)
*   `PwbTenant::Page` (inherits from `Pwb::Page`)
*   `PwbTenant::Content` (inherits from `Pwb::Content`)
*   `PwbTenant::Link` (inherits from `Pwb::Link`)
*   `PwbTenant::Agency` (inherits from `Pwb::Agency`)

## Usage Examples

### Querying Data

```ruby
# Get all props for the CURRENT website only
@props = PwbTenant::Prop.all

# Find a specific prop (raises RecordNotFound if it belongs to another tenant)
@prop = PwbTenant::Prop.find(params[:id])

# Complex queries (still scoped!)
@props = PwbTenant::Prop.where(for_sale: true).order(:price_sale_current_cents)
```

### Creating Data

```ruby
# Automatically assigns website_id = Pwb::Current.website.id
@prop = PwbTenant::Prop.create(
  title: "My New Property",
  description: "Great views!"
)
```

### Associations

When using `PwbTenant` models, associations defined in the parent class (`Pwb::Prop`) are inherited. However, be aware that associations might return `Pwb` instances unless overridden.

## How It Works

These models use the `PwbTenant::ScopedModel` concern which:
1.  Sets `default_scope { where(website_id: Pwb::Current.website&.id) }`
2.  Adds `before_validation` callback to set `website_id`.
3.  Fixes `Globalize` inheritance to ensure translations work correctly.

## Best Practices

*   **Use `PwbTenant` models in Controllers** to ensure data isolation.
*   **Use `Pwb` models in Admin/SuperAdmin contexts** where you might need to access data across tenants (though explicit scoping is still safer).
