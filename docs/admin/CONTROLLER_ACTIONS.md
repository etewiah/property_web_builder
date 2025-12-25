# Admin Controller Actions Matrix

Quick reference of all controller actions (methods) that render pages in admin sections.

## Site Admin Controllers

### Dashboard Controller
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin` | `dashboard/index.html.erb` | Main dashboard with statistics |

### Props Controller
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/props` | `props/index.html.erb` | List all properties with search |
| `show` | GET `/site_admin/props/:id` | `props/show.html.erb` | View property details |
| `edit_general` | GET `/site_admin/props/:id/edit/general` | `props/edit_general.html.erb` | Edit basic property info |
| `edit_text` | GET `/site_admin/props/:id/edit/text` | `props/edit_text.html.erb` | Edit titles/descriptions |
| `edit_sale_rental` | GET `/site_admin/props/:id/edit/sale_rental` | `props/edit_sale_rental.html.erb` | Edit sale/rental listing status |
| `edit_location` | GET `/site_admin/props/:id/edit/location` | `props/edit_location.html.erb` | Edit property location/coordinates |
| `edit_labels` | GET `/site_admin/props/:id/edit/labels` | `props/edit_labels.html.erb` | Edit property features |
| `edit_photos` | GET `/site_admin/props/:id/edit/photos` | `props/edit_photos.html.erb` | Manage property photos |
| `upload_photos` | POST `/site_admin/props/:id/upload_photos` | (redirect) | Handle photo uploads |
| `remove_photo` | DELETE `/site_admin/props/:id/remove_photo` | (redirect) | Remove single photo |
| `reorder_photos` | PATCH `/site_admin/props/:id/reorder_photos` | (redirect) | Reorder photos |
| `update` | PATCH `/site_admin/props/:id` | (redirect) | Update property data |

### Props::SaleListingsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `new` | GET `/site_admin/props/:id/sale_listings/new` | `props/sale_listings/new.html.erb` | Create sale listing |
| `create` | POST `/site_admin/props/:id/sale_listings` | (redirect) | Persist sale listing |
| `edit` | GET `/site_admin/props/:id/sale_listings/:id/edit` | `props/sale_listings/edit.html.erb` | Edit sale listing |
| `update` | PATCH `/site_admin/props/:id/sale_listings/:id` | (redirect) | Update sale listing |
| `destroy` | DELETE `/site_admin/props/:id/sale_listings/:id` | (redirect) | Delete sale listing |

### Props::RentalListingsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `new` | GET `/site_admin/props/:id/rental_listings/new` | `props/rental_listings/new.html.erb` | Create rental listing |
| `create` | POST `/site_admin/props/:id/rental_listings` | (redirect) | Persist rental listing |
| `edit` | GET `/site_admin/props/:id/rental_listings/:id/edit` | `props/rental_listings/edit.html.erb` | Edit rental listing |
| `update` | PATCH `/site_admin/props/:id/rental_listings/:id` | (redirect) | Update rental listing |
| `destroy` | DELETE `/site_admin/props/:id/rental_listings/:id` | (redirect) | Delete rental listing |

### Pages Controller
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/pages` | `pages/index.html.erb` | List all pages |
| `show` | GET `/site_admin/pages/:id` | `pages/show.html.erb` | View page details |
| `edit` | GET `/site_admin/pages/:id/edit` | `pages/edit.html.erb` | Edit page with parts |
| `update` | PATCH `/site_admin/pages/:id` | (redirect) | Update page attributes |
| `settings` | GET `/site_admin/pages/:id/settings` | `pages/settings.html.erb` | Edit page metadata |
| `update_settings` | PATCH `/site_admin/pages/:id/settings` | (redirect) | Update page settings |
| `reorder_parts` | PATCH `/site_admin/pages/:id/reorder_parts` | (JSON) | Reorder page parts |

### Pages::PagePartsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `show` | GET `/site_admin/pages/:id/page_parts/:id` | `pages/page_parts/show.html.erb` | View page part |
| `edit` | GET `/site_admin/pages/:id/page_parts/:id/edit` | `pages/page_parts/edit.html.erb` | Edit page part content |
| `update` | PATCH `/site_admin/pages/:id/page_parts/:id` | (redirect) | Update page part |
| `toggle_visibility` | PATCH `/site_admin/pages/:id/page_parts/:id/toggle_visibility` | (JSON) | Toggle part visibility |

### PagePartsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/page_parts` | `page_parts/index.html.erb` | List all page parts |
| `show` | GET `/site_admin/page_parts/:id` | `page_parts/show.html.erb` | View page part details |

### ContentsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/contents` | `contents/index.html.erb` | List all contents |
| `show` | GET `/site_admin/contents/:id` | `contents/show.html.erb` | View content details |

### MessagesController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/messages` | `messages/index.html.erb` | List all messages |
| `show` | GET `/site_admin/messages/:id` | `messages/show.html.erb` | View message details |

### ContactsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/contacts` | `contacts/index.html.erb` | List all contacts |
| `show` | GET `/site_admin/contacts/:id` | `contacts/show.html.erb` | View contact details |

### UsersController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/users` | `users/index.html.erb` | List website users |
| `show` | GET `/site_admin/users/:id` | `users/show.html.erb` | View user profile |

### EmailTemplatesController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/email_templates` | `email_templates/index.html.erb` | List email templates |
| `show` | GET `/site_admin/email_templates/:id` | `email_templates/show.html.erb` | View template |
| `new` | GET `/site_admin/email_templates/new` | `email_templates/new.html.erb` | Create new template |
| `create` | POST `/site_admin/email_templates` | (redirect) | Persist template |
| `edit` | GET `/site_admin/email_templates/:id/edit` | `email_templates/edit.html.erb` | Edit template |
| `update` | PATCH `/site_admin/email_templates/:id` | (redirect) | Update template |
| `destroy` | DELETE `/site_admin/email_templates/:id` | (redirect) | Delete template |
| `preview` | GET `/site_admin/email_templates/:id/preview` | `email_templates/preview.html.erb` | Preview with sample data |
| `preview_default` | GET `/site_admin/email_templates/preview_default` | `email_templates/preview_default.html.erb` | Preview default template |

### Website::SettingsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `show` | GET `/site_admin/website/settings` | `website/settings/show.html.erb` | Settings hub (tab-based) |
| `show` | GET `/site_admin/website/settings/:tab` | `website/settings/show.html.erb` | Specific settings tab |
| `update` | PATCH `/site_admin/website/settings` | (redirect) | Update settings |
| `update_links` | PATCH `/site_admin/website/settings/links` | (redirect) | Update navigation links |
| `test_notifications` | POST `/site_admin/website/test_notifications` | (redirect) | Test notification config |

**Tabs available**:
- general (company info, locales, currency, analytics)
- appearance (theme, CSS variables, custom CSS)
- navigation (top nav & footer links)
- home (homepage title, display options)
- notifications (Ntfy.sh integration)

### Properties::SettingsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/properties/settings` | `properties/settings/index.html.erb` | List setting categories |
| `show` | GET `/site_admin/properties/settings/:category` | `properties/settings/show.html.erb` | Edit category options |
| `create` | POST `/site_admin/properties/settings/:category` | (redirect) | Create new option |
| `update` | PATCH `/site_admin/properties/settings/:category/:id` | (redirect) | Update option |
| `destroy` | DELETE `/site_admin/properties/settings/:category/:id` | (redirect) | Delete option |

### StorageStatsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `show` | GET `/site_admin/storage_stats` | `storage_stats/show.html.erb` | View storage usage |
| `cleanup` | POST `/site_admin/storage_stats/cleanup` | (redirect) | Clean orphaned files |

### AnalyticsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `show` | GET `/site_admin/analytics` | `analytics/show.html.erb` | Analytics overview dashboard |
| `traffic` | GET `/site_admin/analytics/traffic` | `analytics/traffic.html.erb` | Traffic analytics |
| `properties` | GET `/site_admin/analytics/properties` | `analytics/properties.html.erb` | Property engagement analytics |
| `conversions` | GET `/site_admin/analytics/conversions` | `analytics/conversions.html.erb` | Conversion funnel analytics |
| `realtime` | GET `/site_admin/analytics/realtime` | `analytics/realtime.html.erb` | Real-time visitor tracking |

### DomainsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `show` | GET `/site_admin/domain` | `domains/show.html.erb` | View domain config |
| `update` | PATCH `/site_admin/domain` | (redirect) | Update domain |
| `verify` | POST `/site_admin/domain/verify` | (redirect) | Verify domain ownership |

### OnboardingController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `show` | GET `/site_admin/onboarding` | (varies by step) | Show current onboarding step |
| `show` | GET `/site_admin/onboarding/:step` | `onboarding/{step}.html.erb` | Show specific step |
| `update` | POST `/site_admin/onboarding/:step` | (redirect) | Save step data |
| `skip_step` | POST `/site_admin/onboarding/:step/skip` | (redirect) | Skip current step |
| `skip_step` | GET `/site_admin/onboarding/:step/skip` | (redirect) | Skip current step |
| `complete` | GET `/site_admin/onboarding/complete` | `onboarding/complete.html.erb` | View completion page |
| `restart` | POST `/site_admin/onboarding/restart` | (redirect) | Restart onboarding |

**Steps** (rendered by show action):
- Step 1: `welcome.html.erb`
- Step 2: `profile.html.erb`
- Step 3: `property.html.erb`
- Step 4: `theme.html.erb`
- Step 5: `complete.html.erb`

### TourController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `complete` | POST `/site_admin/tour/complete` | (JSON) | Mark tour as complete |

### ImagesController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/site_admin/images` | `images/index.html.erb` | List images in library |
| `create` | POST `/site_admin/images` | (JSON) | Upload image |

---

## Tenant Admin Controllers

### Dashboard Controller
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin` | `dashboard/index.html.erb` | System overview dashboard |

### WebsitesController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/websites` | `websites/index.html.erb` | List all websites |
| `show` | GET `/tenant_admin/websites/:id` | `websites/show.html.erb` | View website details |
| `new` | GET `/tenant_admin/websites/new` | `websites/new.html.erb` | Create new website |
| `create` | POST `/tenant_admin/websites` | (redirect) | Persist new website |
| `edit` | GET `/tenant_admin/websites/:id/edit` | `websites/edit.html.erb` | Edit website settings |
| `update` | PATCH `/tenant_admin/websites/:id` | (redirect) | Update website |
| `destroy` | DELETE `/tenant_admin/websites/:id` | (redirect) | Delete website |
| `seed` | POST `/tenant_admin/websites/:id/seed` | (redirect) | Seed demo data |
| `retry_provisioning` | POST `/tenant_admin/websites/:id/retry_provisioning` | (redirect) | Retry failed provisioning |

### UsersController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/users` | `users/index.html.erb` | List all users |
| `show` | GET `/tenant_admin/users/:id` | `users/show.html.erb` | View user details |
| `new` | GET `/tenant_admin/users/new` | `users/new.html.erb` | Create new user |
| `create` | POST `/tenant_admin/users` | (redirect) | Persist new user |
| `edit` | GET `/tenant_admin/users/:id/edit` | `users/edit.html.erb` | Edit user |
| `update` | PATCH `/tenant_admin/users/:id` | (redirect) | Update user |
| `destroy` | DELETE `/tenant_admin/users/:id` | (redirect) | Delete user |
| `transfer_ownership` | POST `/tenant_admin/users/:id/transfer_ownership` | (redirect) | Transfer website ownership |

### SubscriptionsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/subscriptions` | `subscriptions/index.html.erb` | List all subscriptions |
| `show` | GET `/tenant_admin/subscriptions/:id` | `subscriptions/show.html.erb` | View subscription details |
| `new` | GET `/tenant_admin/subscriptions/new` | `subscriptions/new.html.erb` | Create subscription |
| `create` | POST `/tenant_admin/subscriptions` | (redirect) | Persist subscription |
| `edit` | GET `/tenant_admin/subscriptions/:id/edit` | `subscriptions/edit.html.erb` | Edit subscription |
| `update` | PATCH `/tenant_admin/subscriptions/:id` | (redirect) | Update subscription |
| `destroy` | DELETE `/tenant_admin/subscriptions/:id` | (redirect) | Delete subscription |
| `activate` | POST `/tenant_admin/subscriptions/:id/activate` | (redirect) | Activate subscription |
| `cancel` | POST `/tenant_admin/subscriptions/:id/cancel` | (redirect) | Cancel subscription |
| `change_plan` | POST `/tenant_admin/subscriptions/:id/change_plan` | (redirect) | Change subscription plan |
| `expire_trials` | POST `/tenant_admin/subscriptions/expire_trials` | (redirect) | Bulk expire trials |

### PlansController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/plans` | `plans/index.html.erb` | List all plans |
| `show` | GET `/tenant_admin/plans/:id` | `plans/show.html.erb` | View plan details |
| `new` | GET `/tenant_admin/plans/new` | `plans/new.html.erb` | Create new plan |
| `create` | POST `/tenant_admin/plans` | (redirect) | Persist plan |
| `edit` | GET `/tenant_admin/plans/:id/edit` | `plans/edit.html.erb` | Edit plan |
| `update` | PATCH `/tenant_admin/plans/:id` | (redirect) | Update plan |
| `destroy` | DELETE `/tenant_admin/plans/:id` | (redirect) | Delete plan |

### DomainsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/domains` | `domains/index.html.erb` | List custom domains |
| `show` | GET `/tenant_admin/domains/:id` | `domains/show.html.erb` | View domain details |
| `edit` | GET `/tenant_admin/domains/:id/edit` | `domains/edit.html.erb` | Edit domain |
| `update` | PATCH `/tenant_admin/domains/:id` | (redirect) | Update domain |
| `verify` | POST `/tenant_admin/domains/:id/verify` | (redirect) | Verify domain |
| `remove` | DELETE `/tenant_admin/domains/:id/remove` | (redirect) | Remove domain |

### SubdomainsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/subdomains` | `subdomains/index.html.erb` | List subdomains |
| `show` | GET `/tenant_admin/subdomains/:id` | `subdomains/show.html.erb` | View subdomain details |
| `new` | GET `/tenant_admin/subdomains/new` | `subdomains/new.html.erb` | Create subdomain |
| `create` | POST `/tenant_admin/subdomains` | (redirect) | Persist subdomain |
| `edit` | GET `/tenant_admin/subdomains/:id/edit` | `subdomains/edit.html.erb` | Edit subdomain |
| `update` | PATCH `/tenant_admin/subdomains/:id` | (redirect) | Update subdomain |
| `destroy` | DELETE `/tenant_admin/subdomains/:id` | (redirect) | Delete subdomain |
| `release` | POST `/tenant_admin/subdomains/:id/release` | (redirect) | Release subdomain |
| `release_expired` | POST `/tenant_admin/subdomains/release_expired` | (redirect) | Release expired reservations |
| `populate` | POST `/tenant_admin/subdomains/populate` | (redirect) | Generate new subdomains |

### AuthAuditLogsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/auth_audit_logs` | `auth_audit_logs/index.html.erb` | List audit logs |
| `show` | GET `/tenant_admin/auth_audit_logs/:id` | `auth_audit_logs/show.html.erb` | View log details |
| `user_logs` | GET `/tenant_admin/auth_audit_logs/user/:user_id` | `auth_audit_logs/user_logs.html.erb` | User login history |
| `ip_logs` | GET `/tenant_admin/auth_audit_logs/ip/:ip` | `auth_audit_logs/ip_logs.html.erb` | IP login history |

### AgenciesController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/agencies` | `agencies/index.html.erb` | List all agencies |
| `show` | GET `/tenant_admin/agencies/:id` | `agencies/show.html.erb` | View agency details |
| `new` | GET `/tenant_admin/agencies/new` | `agencies/new.html.erb` | Create agency |
| `create` | POST `/tenant_admin/agencies` | (redirect) | Persist agency |
| `edit` | GET `/tenant_admin/agencies/:id/edit` | `agencies/edit.html.erb` | Edit agency |
| `update` | PATCH `/tenant_admin/agencies/:id` | (redirect) | Update agency |
| `destroy` | DELETE `/tenant_admin/agencies/:id` | (redirect) | Delete agency |

### EmailTemplatesController (Cross-Tenant)
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/email_templates` | `email_templates/index.html.erb` | List global templates |
| `show` | GET `/tenant_admin/email_templates/:id` | `email_templates/show.html.erb` | View template |
| `new` | GET `/tenant_admin/email_templates/new` | `email_templates/new.html.erb` | Create template |
| `create` | POST `/tenant_admin/email_templates` | (redirect) | Persist template |
| `edit` | GET `/tenant_admin/email_templates/:id/edit` | `email_templates/edit.html.erb` | Edit template |
| `update` | PATCH `/tenant_admin/email_templates/:id` | (redirect) | Update template |
| `destroy` | DELETE `/tenant_admin/email_templates/:id` | (redirect) | Delete template |
| `preview` | GET `/tenant_admin/email_templates/:id/preview` | `email_templates/preview.html.erb` | Preview template |
| `preview_default` | GET `/tenant_admin/email_templates/preview_default` | `email_templates/preview_default.html.erb` | Preview default |

### Data View Controllers (Read-Only)

These controllers provide read-only views into tenant-scoped data:

#### PropsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/props` | `props/index.html.erb` | List all properties |
| `show` | GET `/tenant_admin/props/:id` | `props/show.html.erb` | Property details |

#### PagesController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/pages` | `pages/index.html.erb` | List all pages |
| `show` | GET `/tenant_admin/pages/:id` | `pages/show.html.erb` | Page details |

#### PagePartsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/page_parts` | `page_parts/index.html.erb` | List page parts |
| `show` | GET `/tenant_admin/page_parts/:id` | `page_parts/show.html.erb` | Page part details |

#### ContentsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/contents` | `contents/index.html.erb` | List contents |
| `show` | GET `/tenant_admin/contents/:id` | `contents/show.html.erb` | Content details |

#### MessagesController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/messages` | `messages/index.html.erb` | List messages |
| `show` | GET `/tenant_admin/messages/:id` | `messages/show.html.erb` | Message details |

#### ContactsController
| Action | Path | View | Purpose |
|--------|------|------|---------|
| `index` | GET `/tenant_admin/contacts` | `contacts/index.html.erb` | List contacts |
| `show` | GET `/tenant_admin/contacts/:id` | `contacts/show.html.erb` | Contact details |

---

## Summary

- **Total Page-Rendering Actions**: ~120+
- **List/Index Pages**: ~40
- **Detail/Show Pages**: ~35
- **Edit Pages**: ~25
- **Create/New Pages**: ~15
- **Special Pages** (Analytics, Onboarding, etc.): ~10

## REST Conventions Used

All controllers follow standard REST patterns:

| HTTP Method | Action | Purpose |
|-------------|--------|---------|
| GET | `index` | List all resources |
| GET | `show` | Show single resource |
| GET | `new` | Show new form |
| POST | `create` | Create resource |
| GET | `edit` | Show edit form |
| PATCH/PUT | `update` | Update resource |
| DELETE | `destroy` | Delete resource |
| GET | custom action | Custom action (e.g., `settings`) |
| POST | custom action | Custom action (e.g., `verify`) |

Non-REST actions commonly used:
- `preview`, `preview_default` - Template previews
- `settings`, `update_settings` - Settings pages
- `activate`, `cancel`, `release` - State changes
- `verify`, `remove` - Domain operations
- `skip_step`, `complete`, `restart` - Onboarding flow
- `transfer_ownership` - User operations
- `release_expired`, `populate`, `change_plan`, `expire_trials` - Bulk operations
