# Properties Settings Documentation

Documentation for the Properties Settings feature in PropertyWebBuilder.

## Overview

The Properties Settings feature allows site administrators to manage dropdown options and classification values used throughout property listings, including:

- **Property Types** (Apartment, Villa, Commercial, etc.)
- **Features/Amenities** (Pool, Garden, Air Conditioning, etc.)
- **Property States** (New, Good Condition, Needs Renovation, etc.)
- **Property Labels** (Featured, New on Market, Price Reduced, etc.)

## Documentation Files

### For End Users

- **[User Guide](user_guide.md)** - Step-by-step instructions for managing property settings
  - How to add, edit, and delete entries
  - Multilingual support
  - Best practices and tips
  - Troubleshooting common issues

### For Developers

- **[Developer Guide](developer_guide.md)** - Technical reference for developers
  - Architecture overview
  - Database schema
  - API endpoints
  - Controller and model methods
  - Integration examples
  - Testing guidelines
  - Performance considerations

### For System Administrators

- **[Admin Interface Documentation](admin_interface_documentation.md)** - Documentation of the existing Vue.js admin interface at `/admin`
  - Architecture and components
  - Backend API interactions
  - Settings tabs functionality

## Quick Start

### Accessing Settings

1. Log in to Site Admin at `/site_admin`
2. Navigate to **Properties** → **Settings**
3. Choose a category tab

### Adding an Entry

1. Click "Add New Entry"
2. Fill in translations for all languages
3. Set display order and visibility
4. Click "Create"

## Features

✅ **Multi-language Support** - 16+ languages  
✅ **Tenant Scoped** - Each website has independent settings  
✅ **Live Updates** - Changes appear immediately  
✅ **Sorting** - Control display order  
✅ **Visibility Toggle** - Show/hide specific options  

## Implementation Details

- **Routes**: `/site_admin/properties/settings`
- **Controller**: `SiteAdmin::Properties::SettingsController`
- **Model**: `Pwb::FieldKey`
- **Database**: `pwb_field_keys` table

## Testing

The feature includes comprehensive test coverage:
- Controller specs: `spec/controllers/site_admin/properties/settings_controller_spec.rb`
- System specs: `spec/system/site_admin/properties_settings_spec.rb`

Run tests with:
```bash
rspec spec/controllers/site_admin/properties/settings_controller_spec.rb
rspec spec/system/site_admin/properties_settings_spec.rb
```

## Support

For questions or issues:
- Check the [User Guide](user_guide.md) for common tasks
- Review the [Developer Guide](developer_guide.md) for technical details
- Contact your system administrator

---

*Last Updated: December 2024*
