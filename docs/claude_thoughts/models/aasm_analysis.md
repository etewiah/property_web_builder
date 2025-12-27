# AASM (Acts As State Machine) Gem Analysis for PropertyWebBuilder

## Executive Summary

**Recommendation: AASM implementation would provide MODERATE to HIGH value** with a focus on the **SaleListing and RentalListing models**, which have the most complex state management patterns.

The codebase already has informal state machines implemented through boolean flags and manual callbacks. While the application functions well, AASM would:
- Improve code clarity and maintainability
- Make state transitions more explicit and safer
- Provide better validation for state changes
- Reduce ad-hoc state management logic

## Current State Machine Patterns in Codebase

### 1. **SaleListing and RentalListing Models** (HIGH PRIORITY)

**Location**: 
- `/app/models/pwb/sale_listing.rb`
- `/app/models/pwb/rental_listing.rb`

**Current State Implementation**: Uses 4 boolean columns
- `active` (boolean) - Whether this is the currently active listing for a property
- `visible` (boolean) - Whether listing should appear on the website
- `archived` (boolean) - Whether listing is archived/inactive
- `highlighted` (boolean) - Premium listing status

**State Transitions Implemented**:
```ruby
# Current manual methods:
def activate!
  transaction do
    realty_asset.sale_listings.where.not(id: id).update_all(active: false)
    update!(active: true, archived: false)
  end
end

def deactivate!
  update!(active: false)
end

def archive!
  raise ActiveRecord::RecordInvalid.new(self), "Cannot archive the active listing" if active?
  update!(archived: true, visible: false)
end

def unarchive!
  update!(archived: false)
end
```

**Current Validation Logic**:
- `validate :only_one_active_per_realty_asset, if: :active?`
- `validate :cannot_delete_active_listing, on: :destroy`
- Callbacks: `before_save :deactivate_other_listings, if: :will_activate?`
- Callbacks: `after_save :ensure_active_listing_visible, if: :saved_change_to_active?`

**Complexity Level**: Medium-High
- Multiple boolean interdependencies (archived ↔ active ↔ visible)
- Cross-entity constraints (only one active per parent property)
- Business logic spread across validations, callbacks, and instance methods
- Materialized view refresh logic coupled with state changes

**AASM Benefit**: **HIGH** - Would clearly define valid state transitions and consolidate business logic

**Proposed State Machine** (if implemented):
```
[Draft] --activate--> [Active] --archive--> [Archived]
          <--deactivate--   <--unarchive--

[Draft] <--visible--> [Hidden]
[Active] <--visible--> [Hidden]
[Archived] -> [Hidden] (always)
```

---

### 2. **UserMembership Model** (MEDIUM PRIORITY)

**Location**: `/app/models/pwb/user_membership.rb`

**Current State Implementation**: Uses boolean column with discrete role values
- `active` (boolean) - Whether membership is active
- `role` (string enum) - 'owner', 'admin', 'member', 'viewer' (4 states)

**State Transitions**:
```ruby
# Current scopes indicate state patterns:
scope :active, -> { where(active: true) }
scope :inactive, -> { where(active: false) }

# Role hierarchy logic:
ROLES = %w[owner admin member viewer].freeze
def self.role_hierarchy
  ROLES.each_with_index.to_h
end
```

**Complexity Level**: Low-Medium
- Linear role hierarchy (owner > admin > member > viewer)
- Simple active/inactive toggle
- Role-based permissions checked with `admin?`, `owner?`, `can_manage?`

**AASM Benefit**: **MEDIUM** - Would make role transitions explicit and easier to audit, but current implementation is already quite clean

---

### 3. **Website Model** (LOW-MEDIUM PRIORITY)

**Location**: `/app/models/pwb/website.rb`

**Current State Implementation**:
- `verify_custom_domain!` method suggests domain verification workflow
- `generate_domain_verification_token!` indicates pending verification state
- No explicit status column in schema, but business logic indicates states

**Current Methods Indicating State Workflow**:
```ruby
def generate_domain_verification_token!
  # ... domain verification process
end

def verify_custom_domain!
  # ... custom domain verification
end
```

**Complexity Level**: Low
- Simple workflow: unverified → pending → verified
- No documented validations preventing invalid transitions

**AASM Benefit**: **LOW-MEDIUM** - Would formalize the domain verification workflow, but impact is limited since it's a simple 2-3 state process

---

### 4. **Prop and RealtyAsset Models** (LOW PRIORITY)

**Location**: `/app/models/pwb/prop.rb` and `/app/models/pwb/realty_asset.rb`

**Current State Implementation**:
- Uses boolean flags inherited from sale/rental listings
- Multiple listing-related methods: `for_sale?`, `for_rent?`, `visible?`
- These are computed from associated listings, not stored states

**Current Logic**:
```ruby
def for_sale?
  sale_listings.active.exists?
end

def for_rent?
  rental_listings.active.exists?
end

def visible?
  for_sale? || for_rent?
end
```

**Complexity Level**: Low
- State derived from associations
- No direct state management needed

**AASM Benefit**: **LOW** - Derived state management is appropriate here; AASM not needed

---

### 5. **Content Model** (LOW PRIORITY)

**Location**: `/app/models/pwb/content.rb`

**Current State Implementation**:
- `status` (string column) exists but is not used in model logic
- Column definition found in schema but no corresponding model code

**Complexity Level**: Very Low
- Status column present but dormant

**AASM Benefit**: **LOW** - May be legacy; needs clarification on usage before implementation

---

## Summary of Current State Patterns

### Boolean Flags Found in Schema:
- `pwb_sales_listings.active` (unique constraint)
- `pwb_rental_listings.active` (unique constraint)
- `pwb_sale_listings.visible`, `pwb_rental_listings.visible`
- `pwb_sale_listings.archived`, `pwb_rental_listings.archived`
- `pwb_user_memberships.active`
- `pwb_field_keys.visible`
- `pwb_page_contents.visible_on_page`
- `pwb_agencies`: Multiple boolean flags via `flag_shih_tzu` gem

### Manual State Methods (Bang Methods) Found:
- `SaleListing#activate!`, `SaleListing#deactivate!`, `SaleListing#archive!`, `SaleListing#unarchive!`
- `RentalListing#activate!`, `RentalListing#deactivate!`, `RentalListing#archive!`, `RentalListing#unarchive!`
- `Website#generate_domain_verification_token!`, `Website#verify_custom_domain!`

### Complex Validation Logic:
- Cross-entity constraints (only one active listing per property)
- State-dependent validations (`validate :only_one_active_per_realty_asset, if: :active?`)
- State-dependent callbacks that manage other entities

---

## AASM Benefits & Trade-offs

### Benefits of Implementing AASM:

1. **Clarity**: Explicitly defined state diagrams and transitions
2. **Safety**: Prevents invalid state transitions at the gem level
3. **Auditability**: Can log state changes for compliance/debugging
4. **Reduced Callbacks**: Consolidates scattered before/after hooks
5. **Better Testing**: Easier to test state machines than loose boolean logic
6. **Documentation**: State machines serve as executable documentation
7. **Maintainability**: New developers understand valid states immediately

### Trade-offs:

1. **Gem Dependency**: Adds external dependency (minor concern - AASM is mature)
2. **Refactoring Effort**: Medium effort to migrate SaleListing/RentalListing
3. **Learning Curve**: Team needs to learn AASM DSL
4. **Potential Performance**: Minimal - AASM is very efficient
5. **Migration**: Existing data doesn't need changes; only code logic changes

---

## Recommended Implementation Plan

### Phase 1: SaleListing & RentalListing (High Priority)

These models have the most complex state management and would benefit most from AASM:

```ruby
# Example of what AASM would look like:
class SaleListing < ApplicationRecord
  include AASM

  aasm column: :listing_state do
    state :draft, initial: true
    state :active
    state :archived
    state :deleted

    event :activate do
      transitions from: :draft, to: :active do
        before do
          deactivate_other_listings
        end
        after do
          ensure_visible
          refresh_properties_view
        end
      end
    end

    event :archive do
      transitions from: :active, to: :archived, guard: :can_archive?
    end

    event :deactivate do
      transitions from: :active, to: :draft
    end

    event :restore do
      transitions from: :archived, to: :draft
    end
  end

  def can_archive?
    !active?
  end

  private

  def deactivate_other_listings
    realty_asset.sale_listings.where.not(id: id).update_all(listing_state: :draft)
  end

  def ensure_visible
    update_column(:visible, true) if archived?
  end
end
```

### Phase 2: UserMembership (Medium Priority)

Simpler state machine for user roles and membership status.

### Phase 3: Website (Low Priority)

Document and formalize the domain verification workflow.

---

## Current Gem Dependencies

**Gemfile Analysis**: No state machine gems currently included
- `acts_as_tenant` (multi-tenancy scoping) - unrelated
- `pagy` (pagination) - unrelated
- Various other business logic gems

AASM is **not included** and would be a new dependency.

---

## Conclusion

**AASM would be BENEFICIAL**, particularly for:
1. **SaleListing/RentalListing** - Complex multi-boolean state management
2. **UserMembership** - Explicit role transitions and access control
3. **Website** - Formalizing domain verification workflow

**Complexity in codebase warrants it**: 
- Multiple boolean flags with interdependencies
- Manual validation and callback logic
- Cross-entity state constraints
- Business logic scattered across methods

**Recommended Next Steps**:
1. Start with SaleListing/RentalListing as proof of concept
2. Add AASM gem to Gemfile
3. Create AASM-based version alongside existing code
4. Run full test suite to validate behavior equivalence
5. Gradually refactor related code (scopes, validators, callbacks)
6. Document state machines in architecture documentation
