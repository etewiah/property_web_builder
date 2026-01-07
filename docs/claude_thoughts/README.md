# Claude's Analysis Documents

This directory contains detailed research and analysis documents created during development work. These are exploratory notes, architecture findings, and reference materials.

## External Listings Feature Documents

### 1. **external_listings_exploration.md**
Comprehensive deep-dive into the external listings feature architecture.

**Contents:**
- Overview and high-level architecture
- Detailed breakdown of controllers, views, services
- Data models and their relationships
- Service layer design (Manager, BaseProvider, ResalesOnline)
- Translation strategy
- Routes and initialization
- Caching mechanisms
- Multi-language support
- Current limitations and considerations

**Best for:** Understanding the big picture, architectural decisions, how components fit together.

### 2. **external_listings_file_structure.md**
Quick reference guide showing where everything is located.

**Contents:**
- Complete file structure map with paths
- Quick reference tables
- Method signatures for key classes
- Translation key namespaces
- Data flow diagrams
- Performance considerations
- Provider integration points
- Quick links to specific file locations and line numbers

**Best for:** Finding files quickly, understanding method signatures, quick lookups while working.

### 3. **external_listings_code_snippets.md**
Working code examples and patterns for common tasks.

**Contents:**
- Accessing external feed in controllers/views
- Search examples (basic and full parameters)
- Finding single properties
- Getting similar properties
- Loading and rendering filter options
- Property card and detail view examples
- Filter form with Stimulus controller
- Translation implementation patterns
- Admin configuration setup
- Caching and performance tips
- Error handling examples
- Creating a new provider template

**Best for:** Copy-paste examples, understanding patterns, implementing new features, troubleshooting.

## Using These Documents

### When Starting Work
1. Read **external_listings_exploration.md** for context
2. Use **external_listings_file_structure.md** to locate files
3. Reference **external_listings_code_snippets.md** for implementation patterns

### When Making Changes
1. Check **external_listings_file_structure.md** for affected files
2. Review relevant section in **external_listings_exploration.md** for design rationale
3. Use code snippets as templates

### When Adding New Features
1. Follow patterns in **external_listings_code_snippets.md**
2. Check translation patterns for any new user-visible strings
3. Verify caching considerations if adding new API calls
4. Update this README if adding new documents

## Key Insights

### Architecture
- **Layered design:** Controller → Manager → Provider → API
- **Multi-provider ready:** Easy to add new property feed sources
- **Normalized data:** All providers return consistent data structures
- **Smart caching:** Reduces API calls for repeated searches

### Translations
- **No centralized YAML file** for external_feed keys
- **Inline in views** with defaults
- **Dynamic keys** for property types and features
- **Locale passed throughout** the stack

### Performance
- **Pagination:** Default 24 results per page
- **Caching:** All major operations cached
- **Lazy loading:** Images lazy-loaded on cards
- **Smart pagination:** Shows current ±2 pages, first, and last

### Developer Experience
- **Stimulus for UI polish:** Filter count, debounce
- **Provider registry pattern:** Easy to add new sources
- **Comprehensive error handling:** Graceful degradation
- **Well-documented:** Code has good comments

---

## Website Locking Feature Documents

Located in `website_locking/` subdirectory.

### 1. **website_locking/ARCHITECTURE_SUMMARY.md** (Start Here)
Executive summary of the website locking feature for pre-compiling pages to static HTML.

**Contents:**
- Quick reference overview
- Three-layer architecture (Compilation, Storage, Serving)
- Data model changes
- Key components
- Implementation roadmap (4 phases)
- Performance impact (10-15x faster)
- Success criteria

**Best for:** Quick overview, sprint planning, stakeholder communication.

### 2. **website_locking/website_locking_architecture_investigation.md**
Deep technical investigation of current rendering pipeline and proposed changes.

**Contents:**
- Current page rendering flow
- Dynamic vs. static content analysis
- PaletteCompiler pattern (precedent)
- Detailed file inventory
- Challenges and gotchas
- Implementation suggestions

**Best for:** Developers, detailed technical planning.

### 3. **website_locking/rendering_pipeline_diagram.md**
Visual ASCII diagrams showing current and proposed architecture.

**Best for:** Visual learners, whiteboarding, presentations.

### 4. **website_locking/website_locking_code_examples.md**
Implementation-ready code examples.

**Contents:**
- Database migration
- Model definitions
- PageCompiler service
- Controller modifications
- RSpec tests
- Rake tasks

**Best for:** Developers implementing the feature.

---

## Document Maintenance

These documents should be updated when:
- Major architectural changes are made
- New providers are added
- Translation strategy changes
- Performance optimizations are implemented
- New views or controllers are created

Keep them in the `docs/claude_thoughts/` directory for easy discovery.

