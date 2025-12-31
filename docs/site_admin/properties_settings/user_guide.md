# Properties Settings - User Guide

Complete guide for managing property types, features, states, and labels in your PropertyWebBuilder website.

## Overview

The Properties Settings feature allows you to customize dropdown options and labels used throughout your property listings. This includes:

- **Property Types** - Categories like Apartment, Villa, Commercial
- **Features** - Amenities like Pool, Garden, Air Conditioning  
- **Property States** - Conditions like New, Good, Needs Renovation
- **Property Labels** - Tags like Featured, Sold, Price Reduced

All settings are **tenant-scoped**, meaning each website has its own independent configuration.

## Accessing Settings

1. Log in to your site admin panel at `/site_admin`
2. Click **Properties** in the left sidebar
3. Click **Settings** (gear icon) under Properties
4. Choose a category tab at the top

**URL**: `http://your-site.localhost:3000/site_admin/properties/settings`

## Managing Settings

### Adding a New Entry

1. Navigate to the desired category (e.g., Property Types)
2. Click the **Add New Entry** button
3. Fill in the name in all required languages
   - At minimum, provide the English (EN) name
   - Add translations for other languages as needed
4. Set the **Display Order** (lower numbers appear first)
5. Check **Visible** to show in dropdowns
6. Click **Create**

**Example**: Adding "Townhouse" as a property type

```
EN: Townhouse
ES: Casa adosada
FR: Maison de ville
Display Order: 5
Visible: ✓
```

### Editing an Entry

1. Find the entry in the table
2. Click the **Edit** button
3. Update the translations, order, or visibility
4. Click **Update**

### Deleting an Entry

1. Find the entry in the table
2. Click the **Delete** button  
3. Confirm the deletion

**⚠ Warning**: Deleting a setting will affect all properties using it.

## Category Guides

### Property Types

Define the main categories of properties you list.

**Common Examples**: Apartment, Villa, Townhouse, Commercial Property, Office, Land, Warehouse

### Features (Amenities)

Checklist of amenities properties may have.

**Common Examples**: Air Conditioning, Pool, Garden, Terrace, Garage, Elevator, Sea Views

### Property States

Describe the physical condition of properties.

**Common Examples**: New Construction, Excellent, Good Condition, Needs Renovation

### Property Labels

Special tags/badges to highlight properties.

**Common Examples**: Featured, New on Market, Price Reduced, Sold, Rented, Reserved

## Multilingual Support

The system supports 16+ languages. Always provide English as the fallback.

## Troubleshooting

**Setting Not Appearing**: Check "Visible" is checked and refresh the page  
**Can't Delete**: Remove the setting from all properties first  
**Changes Not Showing**: Clear browser cache or restart Rails server

## Tips & Best Practices

✅ Keep names concise, provide translations, use consistent terminology  
❌ Don't create duplicates, use abbreviations, or delete settings in use

---

*Last Updated: December 2024*
