# Social Sharing Component

A reusable partial for adding social media sharing buttons to any page.

## Location

`app/views/pwb/shared/_social_sharing.html.erb`

## Usage

### Basic Usage (Default Style)

```erb
<%= render 'pwb/shared/social_sharing',
    url: request.original_url,
    title: @property_details.title %>
```

This renders centered share buttons with FontAwesome icons and a top border.

### Bologna Theme Style (Phosphor Icons)

```erb
<%= render 'pwb/shared/social_sharing',
    url: request.original_url,
    title: @property_details.title,
    icon_style: :phosphor,
    style: :bologna %>
```

This renders left-aligned share buttons with Phosphor icons and rounded button styling.

### Custom Networks

```erb
<%= render 'pwb/shared/social_sharing',
    url: request.original_url,
    title: @page.title,
    networks: [:facebook, :whatsapp] %>
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `url` | String | `request.original_url` | The URL to share (required) |
| `title` | String | `''` | The title/text to share (required) |
| `icon_style` | Symbol | `:fontawesome` | Icon library: `:fontawesome` or `:phosphor` |
| `style` | Symbol | `:default` | Layout style: `:default` or `:bologna` |
| `networks` | Array | `[:facebook, :linkedin, :twitter, :whatsapp]` | Networks to display |

## Supported Networks

- **Facebook** - Opens Facebook share dialog
- **LinkedIn** - Opens LinkedIn share dialog
- **Twitter** - Opens Twitter/X tweet composer
- **WhatsApp** - Opens WhatsApp with pre-filled message

## Styles

### Default Style
- Centered layout with `justify-center`
- Top border separator (`border-t border-gray-100`)
- Padding: `py-6`
- Icons styled individually with hover effects

### Bologna Style
- Left-aligned layout
- Rounded circular buttons (40x40px)
- Background colors with hover transitions
- No container border (wrapper provides styling)

## Examples

### Property Detail Page (Default/Brisbane Theme)

```erb
<!-- In app/themes/default/views/pwb/props/show.html.erb -->
<%= render 'pwb/shared/social_sharing',
    url: request.original_url,
    title: @property_details.title %>
```

### Property Detail Page (Bologna Theme)

```erb
<!-- In app/themes/bologna/views/pwb/props/show.html.erb -->
<div class="border-t border-warm-gray-100 pt-8">
  <p class="text-warm-gray-500 text-sm mb-4">Share this property:</p>
  <%= render 'pwb/shared/social_sharing',
      url: request.original_url,
      title: @property_details.title,
      icon_style: :phosphor,
      style: :bologna %>
</div>
```

### Blog Post (Hypothetical)

```erb
<%= render 'pwb/shared/social_sharing',
    url: blog_post_url(@post),
    title: @post.title,
    networks: [:facebook, :twitter, :linkedin] %>
```

## Adding New Networks

To add a new network (e.g., Pinterest), edit `_social_sharing.html.erb`:

1. Add the share URL to `share_urls` hash
2. Add icons for both FontAwesome and Phosphor to `icons` hash
3. Add link classes for both styles to `link_classes` hash
4. Add a title to `titles` hash
5. Update the default `networks` array if it should be shown by default

## Migration from Vue.js

This component replaces the deprecated Vue.js `<social-sharing>` component that used inline templates:

```erb
<!-- OLD (deprecated Vue.js) -->
<social-sharing inline-template>
  <network network="facebook">...</network>
</social-sharing>

<!-- NEW (ERB partial) -->
<%= render 'pwb/shared/social_sharing', url: ..., title: ... %>
```

## Dependencies

- **FontAwesome** - For default icon style (`fa fa-*` classes)
- **Phosphor Icons** - For Bologna theme (`ph ph-*` classes)
- Both icon libraries should already be loaded in the application layout
