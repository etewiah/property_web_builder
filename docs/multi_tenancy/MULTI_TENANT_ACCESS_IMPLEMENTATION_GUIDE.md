# Multi-Website Role-Based Access Control Implementation Guide

This document details the technical implementation of the multi-website role-based access control system in PropertyWebBuilder.

## Overview

The goal is to allow a single user account to access multiple websites (tenants) with different roles on each website. This replaces the previous single-website `admin` boolean flag.

## Architecture

### Database Schema

We introduce a new join table `pwb_user_memberships` to handle the many-to-many relationship between Users and Websites.

```ruby
create_table :pwb_user_memberships do |t|
  t.references :user, null: false
  t.references :website, null: false
  t.string :role, null: false, default: 'member'
  t.boolean :active, default: true, null: false
  t.timestamps
  
  # Unique constraint ensures one role per user per website
  t.index [:user_id, :website_id], unique: true
end
```

### Roles

The system supports the following hierarchical roles:

1. **Owner** (`owner`): Full access to the website, can manage other admins/owners.
2. **Admin** (`admin`): Can manage website content and settings.
3. **Member** (`member`): Regular authenticated user (e.g., for favorites, saved searches).
4. **Viewer** (`viewer`): Read-only access (future use).

### Models

#### 1. UserMembership (`app/models/pwb/user_membership.rb`)
The join model containing the role logic.

- **Validations**: Ensures role is valid and user-website pair is unique.
- **Scopes**: `active`, `admins`, `owners`, `for_website`.
- **Methods**: `admin?`, `owner?`, `can_manage?`.

#### 2. User (`app/models/pwb/user.rb`)
Updated to support multiple websites.

- **Associations**:
  ```ruby
  has_many :user_memberships
  has_many :websites, through: :user_memberships
  ```
- **Helper Methods**:
  - `admin_for?(website)`: Checks if user has admin/owner role on specific website.
  - `role_for(website)`: Returns the role string.
  - `accessible_websites`: Returns list of websites user can access.

#### 3. Website (`app/models/pwb/website.rb`)
Updated to track its users.

- **Associations**:
  ```ruby
  has_many :user_memberships
  has_many :users, through: :user_memberships
  ```
- **Helper Methods**:
  - `admins`: Returns list of admin users for this website.

### Service Layer

#### UserMembershipService (`app/services/pwb/user_membership_service.rb`)
Centralizes logic for managing permissions.

- `grant_access(user, website, role)`
- `revoke_access(user, website)`
- `change_role(user, website, new_role)`

### Authentication & Authorization Flow

1. **Request**: User attempts to access Admin Panel for `tenant-a.example.com`.
2. **Authentication**: Devise authenticates the `User`.
3. **Authorization**: `AdminPanelController` checks:
   ```ruby
   # Old check
   current_user.admin? && current_user.website == current_website
   
   # New check
   current_user.admin_for?(current_website)
   ```
4. **Result**: Access granted only if a valid, active `UserMembership` with `admin` or `owner` role exists for that specific website.

## Migration Strategy

To ensure zero downtime and data integrity:

1. **Database Migration**: Create the table (Done).
2. **Code Deployment**: Deploy new models and updated logic.
3. **Data Migration**: Run a script to migrate existing users:
   - Iterate through all users with `website_id`.
   - Create `UserMembership` for that website.
   - If `user.admin` was true, set role to `admin`.
   - Else set role to `member`.
4. **Cleanup**: Eventually remove `website_id` and `admin` columns from `pwb_users` table (future phase).

## Usage Examples

### Granting Admin Access
```ruby
user = Pwb::User.find_by(email: 'alice@example.com')
website = Pwb::Website.find_by(subdomain: 'tenant-a')

Pwb::UserMembershipService.grant_access(
  user: user,
  website: website,
  role: 'admin'
)
```

### Checking Permissions
```ruby
if current_user.admin_for?(current_website)
  # Show admin panel
end
```

## Security Considerations

- **Isolation**: Permissions are strictly scoped to `website_id`. Being an admin on Website A grants zero privileges on Website B.
- **Role Hierarchy**: Only Owners can grant Owner privileges (enforced in Service layer).
- **Audit**: All membership changes should be logged (future enhancement).
