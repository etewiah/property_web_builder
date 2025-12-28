# Media Library Documentation Index

## Overview

PropertyWebBuilder currently has a **fragmented image management system** with three separate photo models (PropPhoto, ContentPhoto, WebsitePhoto) and no unified Media Library feature. This documentation explores the current system and provides a comprehensive plan for building a proper Media Library.

## Documentation Files

### 1. Media_Library_Current_State.md
**Length**: 13KB | **Focus**: Analysis of existing system

The most comprehensive document describing what currently exists:
- Detailed schema and associations for all 3 photo models
- Current controllers (SiteAdmin and Editor)
- ImageGalleryBuilder service
- ImagesHelper methods
- ExternalImageSupport concern
- Storage configuration (local disk + Cloudflare R2)
- Detailed list of gaps and limitations
- What needs to be built for proper Media Library

**Start here if you want to understand the current implementation.**

### 2. Media_Library_Architecture_Plan.md
**Length**: 19KB | **Focus**: Design of new Media Library system

Complete architecture and design for building the new system:
- High-level architecture diagrams (ASCII art)
- Complete database schema (Media, MediaFolder, MediaTag, MediaAttachment)
- Model structure and associations
- Controller routes and endpoints
- Service layer design (MediaService, MediaValidator, MediaOptimizer)
- Views and frontend components
- Complete API specification
- 4-phase implementation plan
- Multi-tenancy and security considerations
- Performance optimization strategies

**Use this to understand how to build the new system.**

### 3. Media_Library_Quick_Reference.md
**Length**: 9.5KB | **Focus**: Quick lookup guide

Fast reference for developers:
- File locations for core components
- Database schema quick view
- Key methods and helpers
- Current upload flow diagram
- Common gotchas and important notes
- What needs to be built (checklist)
- Getting started checklist
- Testing patterns
- Rails/Ruby references

**Bookmark this for quick lookups while coding.**

### 4. Media_Library_Code_Examples.md
**Length**: 16KB | **Focus**: Real code examples

Actual code from the system and patterns to follow:
- Example 1: PropPhoto model (basic ActiveStorage + concern)
- Example 2: ExternalImageSupport concern (shared functionality)
- Example 3: ImageGalleryBuilder service (business logic)
- Example 4: SiteAdmin::ImagesController (API patterns)
- Example 5: ImagesHelper (rendering patterns)
- Patterns to follow in new implementation
- Testing examples (specs and factories)
- Migration and factory examples

**Reference this when writing new code to maintain consistency.**

## Quick Start for Media Library Implementation

### Understanding the Current System (1-2 hours)
1. Read: Media_Library_Current_State.md - understand what exists
2. Skim: Media_Library_Code_Examples.md - see actual code
3. Reference: Media_Library_Quick_Reference.md - file locations and gotchas

### Designing the New System (2-4 hours)
1. Read: Media_Library_Architecture_Plan.md - understand design
2. Review: Database schema section - understand data model
3. Review: Model structure section - understand associations

### Building Phase 1 (6-10 hours)
1. Create models: Media, MediaFolder, MediaTag, MediaAttachment
2. Create migrations using schema from architecture plan
3. Create MediaService for upload/delete
4. Create API controller for CRUD
5. Write comprehensive tests
6. Reference: Media_Library_Code_Examples.md for patterns

### Building Phase 2+ (ongoing)
1. Build admin UI (grid view, upload, search)
2. Implement media picker component
3. Integrate with page parts and properties
4. Add enhancements (editing, bulk operations)

## Key Takeaways

### Current System Problems
- **Fragmented**: 3 separate photo models with no unified interface
- **Limited metadata**: Only description, folder, sort_order (no alt text, dimensions, etc.)
- **No organization**: Folder column used only for source tracking, no real hierarchy
- **Basic upload**: Simple file upload with no drag-drop, validation details, or batch support
- **No UI**: Admin interfaces are mostly JSON responses, no Media Library UI

### Current System Strengths
- ✅ ActiveStorage integration (mature, well-tested)
- ✅ Cloudflare R2 support with CDN ready
- ✅ Multi-tenancy scoping patterns established
- ✅ Image optimization helpers (WebP, variants)
- ✅ Error handling and logging practices

### Solution: Unified Media Library
- Single Media model for all media types
- Proper folder hierarchy with MediaFolder
- Rich metadata (title, alt_text, dimensions, mime_type)
- MediaAttachment for tracking usage
- Admin UI with grid/list views
- Media picker component for editors
- API for programmatic access

## Architecture at a Glance

```
User → Admin UI ↔ API Controller ↔ MediaService → Media Model ↔ ActiveStorage ↔ R2/CDN
                                    ↓
                        MediaValidator, MediaOptimizer
```

**Models**: Media → MediaFolder (1-many), Media → MediaTag (many-many), Media → MediaAttachment (1-many)

**API**: GET/POST/PATCH/DELETE /site_admin/api/media

**Storage**: ActiveStorage with Cloudflare R2 backend + CDN

## File Paths for Reference

### Models to Create
```
app/models/pwb/media.rb
app/models/pwb/media_folder.rb
app/models/pwb/media_tag.rb
app/models/pwb/media_attachment.rb
```

### Controllers to Create
```
app/controllers/site_admin/media_controller.rb
app/controllers/site_admin/api/media_controller.rb
app/controllers/site_admin/media_folders_controller.rb
```

### Services to Create
```
app/services/pwb/media_service.rb
app/services/pwb/media_validator.rb
app/services/pwb/media_optimizer.rb
```

### Views to Create
```
app/views/site_admin/media/index.html.erb
app/views/site_admin/media/_grid.html.erb
app/views/site_admin/media/_list.html.erb
app/views/site_admin/media/_upload_area.html.erb
app/views/site_admin/media/_picker.html.erb
```

### Tests to Create
```
spec/models/pwb/media_spec.rb
spec/models/pwb/media_folder_spec.rb
spec/services/pwb/media_service_spec.rb
spec/requests/site_admin/api/media_spec.rb
spec/controllers/site_admin/media_controller_spec.rb
```

### Migrations to Create
```
db/migrate/[timestamp]_create_pwb_media.rb
db/migrate/[timestamp]_create_pwb_media_folders.rb
db/migrate/[timestamp]_create_pwb_media_tags.rb
db/migrate/[timestamp]_create_pwb_media_attachments.rb
```

## Implementation Timeline Estimate

- **Phase 1 (Foundation)**: 1-2 weeks
  - Models, migrations, service, basic API
  - Unit and integration tests

- **Phase 2 (Admin UI)**: 1-2 weeks
  - Grid/list views, upload, search, filtering
  - Edit metadata views

- **Phase 3 (Integration)**: 1 week
  - Media picker for editors
  - Usage tracking
  - Existing image support

- **Phase 4 (Enhancements)**: 1-2 weeks
  - Image editing, bulk operations
  - Advanced search, analytics

**Total estimated effort**: 4-7 weeks for full Media Library

## Key Decisions Made in Plan

1. **Model hierarchy**: Media as base, with MediaFolder for organization
2. **Polymorphic attachments**: Track usage via MediaAttachment
3. **Soft deletes**: Keep deleted files for potential recovery
4. **Tenant scoping**: All media scoped to website via website_id
5. **ActiveStorage**: Consistent with existing system
6. **R2 storage**: Leverage existing Cloudflare setup
7. **Metadata**: Title, description, alt_text (accessibility), file metadata

## Decisions to Make Before Starting

1. **Backwards compatibility**: Will we migrate existing PropPhoto/ContentPhoto/WebsitePhoto?
2. **Permission model**: Should site admins only manage their own media?
3. **Storage limits**: Should media library have size/count limits per website?
4. **Image editing**: In-admin cropping/resizing or defer to Phase 4?
5. **API stability**: Should API be public or internal only?

## Related Documentation

- **CLAUDE.md** - Project guidelines (in repo root)
- **docs/architecture/** - System architecture decisions
- **docs/seeding/** - Seed data documentation
- **docs/multi_tenancy/** - Multi-tenancy patterns

## Questions or Changes?

If you need to:
- **Modify the design**: Update Media_Library_Architecture_Plan.md
- **Document decisions**: Update Media_Library_Current_State.md
- **Add examples**: Update Media_Library_Code_Examples.md
- **Quick lookup**: Reference Media_Library_Quick_Reference.md

## Next Steps

1. ✅ Understand current state (read Media_Library_Current_State.md)
2. ✅ Review architecture plan (read Media_Library_Architecture_Plan.md)
3. ✅ Decide on implementation timeline
4. ⬜ Create feature branch
5. ⬜ Generate models and migrations
6. ⬜ Implement MediaService and validators
7. ⬜ Create API endpoints
8. ⬜ Build admin UI
9. ⬜ Write comprehensive tests
10. ⬜ Create PR for review
