# Investigation: Missing Properties During Website Provisioning

## Summary
Website `steady-pond-45` (ID: 11) has `provisioning_state: 'live'` with owner and agency records, but has **0 properties**. This investigation identifies why properties weren't seeded during the provisioning workflow.

## Key Findings

### 1. Provisioning Workflow Architecture

The provisioning flow is orchestrated by `Pwb::ProvisioningService` (located at `app/services/pwb/provisioning_service.rb`) with these sequential steps:

1. **Owner Assignment** → `owner_assigned` state
2. **Agency Creation** → `agency_created` state  
3. **Navigation Links** → `links_created` state
4. **Field Keys** → `field_keys_created` state
5. **Property Seeding** (OPTIONAL) → `properties_seeded` state
6. **Final Verification** → `ready` state
7. **Email Verification Lock** → `locked_pending_email_verification` state
8. **Go Live** → `live` state

### 2. Property Seeding Logic

**File:** `app/services/pwb/provisioning_service.rb` (lines 172-275)

The `provision_website` method handles property seeding in Step 4 (lines 228-236):

```ruby
# Step 4: Seed properties (optional)
Rails.logger.info("[Provisioning] Seeding properties for website #{website.id} (skip=#{skip_properties})")
if skip_properties
  website.skip_properties!
else
  seed_properties_for_website(website)
  website.seed_properties!
end
report_progress(progress_block, website, 'properties_seeded', 80)
```

**Critical Detail:** The `skip_properties` parameter controls whether properties are seeded.

### 3. Where Properties Get Seeded

The `seed_properties_for_website` method (lines 388-405) tries to seed properties in this order:

1. **First, tries to use a Seed Pack** (lines 391-394):
   ```ruby
   # Try seed pack first
   if try_seed_pack_step(website, :properties)
     return
   end
   ```
   
2. **Falls back to basic seeder** if seed pack fails (lines 397-404):
   ```ruby
   # Fallback: use basic seeder for properties only
   begin
     seeder = Pwb::Seeder.new
     seeder.seed_properties_for_website(website) if seeder.respond_to?(:seed_properties_for_website)
   rescue StandardError => e
     Rails.logger.warn("[Provisioning] Property seeding failed (non-fatal): #{e.message}")
     # Properties are optional, don't fail provisioning
   end
   ```

### 4. Seed Pack Mechanism

**File:** `lib/pwb/seed_pack.rb`

The `try_seed_pack_step` method (lines 409-440) attempts to call seed pack methods:

```ruby
def try_seed_pack_step(website, step)
  pack_name = website.seed_pack_name || 'base'
  
  begin
    if defined?(Pwb::SeedPack)
      seed_pack = Pwb::SeedPack.find(pack_name)
      
      case step
      when :properties
        seed_pack.seed_properties!(website: website) if seed_pack.respond_to?(:seed_properties!)
        return true  # Properties are optional, just return true
      end
    end
  rescue Pwb::SeedPack::PackNotFoundError
    # Pack doesn't exist, use fallback
  rescue NoMethodError
    # Method doesn't exist on pack, use fallback
  rescue StandardError => e
    Rails.logger.warn("[Provisioning] SeedPack step '#{step}' failed: #{e.message}")
  end
  
  false
end
```

**Problem #1:** The method returns `true` immediately without checking if properties were actually created (line 428).

### 5. Seed Pack Configuration

**File:** `db/seeds/packs/base/pack.yml`

The base pack contains:
- `field_keys.yml` - Property field configuration
- `links.yml` - Navigation links
- **NO `properties` directory** - No property data to seed!

The base pack does NOT include any property definitions. It only has structure (field keys and links).

### 6. Website Configuration During Provisioning

Looking at the `configure_site` method (lines 100-167):

```ruby
website = Website.new(
  subdomain: validation[:normalized],
  site_type: site_type,
  provisioning_state: 'pending',
  seed_pack_name: seed_pack_for_site_type(site_type)  # <-- This line
)
```

The `seed_pack_for_site_type` method (lines 302-309):

```ruby
def seed_pack_for_site_type(site_type)
  case site_type
  when 'residential' then 'base'  # Will be 'residential' when pack exists
  when 'commercial' then 'base'   # Will be 'commercial' when pack exists
  when 'vacation_rental' then 'base'  # Will be 'vacation_rentals' when pack exists
  else 'base'
  end
end
```

**Problem #2:** ALL site types currently use the `'base'` pack, which has no properties.

### 7. Missing Fallback Implementation

The fallback logic calls `seeder.seed_properties_for_website(website)`, but:

**File:** `lib/pwb/seeder.rb` (lines 38-121)

The `Pwb::Seeder` class does NOT have a `seed_properties_for_website` method! 

It has `seed_properties` (line 102), which:
- Only seeds if the website has fewer than 4 properties (line 103)
- Uses hardcoded YAML files from `db/yml_seeds/prop/` directory
- Does NOT accept a website parameter in the fallback call

**Problem #3:** The fallback seeder call will silently fail because the method doesn't exist.

## Root Causes

There are THREE independent reasons properties weren't seeded:

### Root Cause #1: Incomplete Seed Pack
The `base` seed pack (assigned to all websites) contains only metadata (field_keys, links) and NO properties directory. This is by design - it's a foundation pack meant to be inherited.

### Root Cause #2: Try/Catch Silently Succeeds
The `try_seed_pack_step` method for properties (line 428) returns `true` unconditionally:
```ruby
when :properties
  seed_pack.seed_properties!(website: website) if seed_pack.respond_to?(:seed_properties!)
  return true  # <-- ALWAYS returns true, even if no properties exist!
```

This means:
- If the pack has a `seed_properties!` method, it's called (or silently skipped if method missing)
- The method returns `true` regardless of whether properties were actually created
- This prevents the fallback seeder from ever running

### Root Cause #3: Missing Fallback Implementation
The fallback code tries to call a non-existent method:
```ruby
seeder.seed_properties_for_website(website)  # This method doesn't exist!
```

The `Pwb::Seeder` class has `seed_properties` (no parameters), not `seed_properties_for_website`.

## Evidence

For website ID 11 (steady-pond-45):
- `provisioning_state: 'live'` ✓ (successfully provisioned)
- `seed_pack_name: 'base'` (confirmed in code path)
- `realty_assets.count: 0` (no properties)
- `user_memberships.count: 1` (owner exists) ✓
- `agency.present?: true` (agency exists) ✓

The state machine shows properties are optional for provisioning (Step 5 vs Step 5b). The website can skip properties and still go live. Since the base pack has no properties, and the fallback silently fails, zero properties are created.

## How Property Seeding Should Work

**Intended Design (Packs with Properties):**
1. Website assigned a seed pack during `configure_site`
2. During `provision_website`, call `try_seed_pack_step(website, :properties)`
3. Seed pack's `seed_properties!` method creates properties from its `properties/` directory
4. If pack doesn't have property files, fallback to basic seeder
5. Transition to `properties_seeded` state

**Current Reality:**
1. Website assigned 'base' pack (which has NO properties)
2. `try_seed_pack_step` returns `true` immediately
3. Fallback is never attempted (return happened already)
4. Transitions to `properties_seeded` state (but actually 0 properties)

## Solution Path

To fix property seeding, choose one or more approaches:

### Option A: Add Properties to Base Pack
Create `db/seeds/packs/base/properties/` with sample property YAML files. The base pack would then seed default properties for all sites.

### Option B: Create Type-Specific Packs
Implement residential, commercial, and vacation_rental packs as mentioned in the code comments:
```ruby
when 'residential' then 'residential'      # Currently 'base'
when 'commercial' then 'commercial'        # Currently 'base'
when 'vacation_rental' then 'vacation_rentals'  # Currently 'base'
```

Each pack would inherit from base and add type-specific properties.

### Option C: Fix the Fallback Implementation
Make the fallback actually work by:
1. Implementing `seed_properties_for_website` in `Pwb::Seeder` class
2. Fix `try_seed_pack_step` to return `false` if no properties actually exist (line 428)
3. Allow fallback to execute and seed from default YAML files

### Option D: Make Properties Required (Not Recommended)
Remove the `skip_properties` option and require properties. But this changes provisioning semantics.

## Related Code Files

- **Provisioning Service:** `/app/services/pwb/provisioning_service.rb` (228-236, 388-405)
- **Website Model:** `/app/models/pwb/website.rb` (102-112 - state transitions)
- **Seed Pack:** `/lib/pwb/seed_pack.rb` (435-450, 409-440)
- **Basic Seeder:** `/lib/pwb/seeder.rb` (100-116)
- **Base Pack Config:** `/db/seeds/packs/base/pack.yml`
- **Provisioning Rake Tasks:** `/lib/tasks/provisioning.rake` (148, 390+)

## Recommendations

1. **Immediate**: For newly provisioned websites, apply a seed pack with properties:
   ```bash
   rake pwb:seed_packs:apply[base,WEBSITE_ID]
   ```
   
   Or manually create a property-bearing seed pack and assign it.

2. **Short-term**: Implement Option B (type-specific packs) or C (fix fallback) based on product requirements.

3. **Documentation**: Update comments in `provisioning_service.rb` (line 228) to clarify that properties are optional and may be empty.

4. **Testing**: Add provisioning tests that verify property seeding actually creates properties when packs have property data.
