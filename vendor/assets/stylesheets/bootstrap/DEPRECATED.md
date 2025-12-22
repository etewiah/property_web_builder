# Bootstrap CSS - DEPRECATED

**Status**: Deprecated as of December 2024

## Notice

The Bootstrap CSS framework in this directory is **deprecated** and will no longer be actively maintained. The project is migrating to Tailwind CSS for all styling needs.

## Current State

- Bootstrap 3.x styles are still bundled for legacy compatibility
- Used primarily in the admin panel (`pwb-admin.scss`)
- Some legacy theme components still reference Bootstrap classes

## Recommendations

- **For new themes**: Use Tailwind CSS (see `app/assets/stylesheets/tailwind-*.css`)
- **For new components**: Use Tailwind utility classes
- **For existing code**: Continue using Bootstrap, but plan migration to Tailwind

## Migration Path

| Bootstrap Class | Tailwind Equivalent |
|----------------|---------------------|
| `.container` | `.container mx-auto px-4` |
| `.row` | `.flex flex-wrap` |
| `.col-md-6` | `.w-full md:w-1/2` |
| `.btn btn-primary` | `.px-4 py-2 bg-blue-600 text-white rounded` |
| `.form-control` | `.w-full px-3 py-2 border rounded` |
| `.hidden-xs` | `.hidden sm:block` |
| `.text-center` | `.text-center` |

## Themes Using Tailwind (Recommended)

- `default` - Modern Tailwind theme
- `brisbane` - Luxury real estate Tailwind theme  
- `bologna` - European style Tailwind theme

## Legacy Themes (Bootstrap)

These themes still use Bootstrap and should be migrated:
- Legacy admin panel styles
- Some older page part templates

## Why Deprecated?

- Tailwind provides more flexibility and smaller bundle sizes
- Better alignment with modern CSS practices
- Reduced CSS conflicts between frameworks
- Improved performance with PurgeCSS

## Future

Bootstrap files may be removed in a future major version once all admin panel components are migrated to Tailwind.
