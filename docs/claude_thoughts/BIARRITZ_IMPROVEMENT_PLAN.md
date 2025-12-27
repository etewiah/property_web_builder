# Biarritz Theme Improvement Plan

**Created:** 2025-12-27  
**Status:** Planning Phase  
**Goal:** Transform Biarritz from basic copy to polished coastal theme

---

## Current Issues Analysis

### 1. **Lack of Theme Identity**
- Currently just copied from default theme templates
- No distinctive coastal/French Basque design elements
- Missing Biarritz-specific components and styling
- Colors defined but not consistently applied

### 2. **Visual Design Problems**
- Generic header/navigation (copied from default)
- No coastal visual elements (waves, beach colors, etc.)
- Missing elegant French Basque typography
- Tailwind CSS file exists but templates don't use theme-specific classes

### 3. **Missing Custom Components**
- No custom hero sections
- No coastal-themed property cards
- No wave dividers or decorative elements
- Generic buttons/CTAs

---

## Improvement Strategy

### Phase 1: Visual Identity & Branding (Quick Wins)

**Priority:** HIGH | **Time:** 2-3 hours

#### A. Header & Navigation Redesign
**Current:** Generic blue gradient header  
**Target:** Elegant coastal navigation with French Basque feel

**Actions:**
1. Create sophisticated header with:
   - Subtle ocean wave SVG pattern in background
   - Elegant serif font (Playfair Display) for logo
   - Refined navigation pills with hover effects
   - Coastal color scheme (deep blue → sand gradient)

2. Add sticky header with smooth transitions
3. Implement elegant mobile menu (side drawer with coastal styling)

**Reference:** Barcelona theme has good structure - adapt with coastal colors

#### B. Typography System
**Current:** Generic fonts  
**Target:** French Basque elegance

**Actions:**
1. Primary font: Open Sans (clean, readable)
2. Heading font: Playfair Display (elegant serif)
3. Accent font: Montserrat (modern sans-serif for CTAs)
4. Define type scale in CSS variables
5. Apply consistently across all templates

#### C. Color Palette Application
**Current:** Colors defined but not used  
**Target:** Consistent coastal color scheme

**Defined Colors:**
- Primary: `#0C4A6E` (Deep Ocean Blue)
- Secondary: `#D97706` (Warm Amber/Sand)
- Accent: `#FBBF24` (Golden Sunset)

**Actions:**
1. Update all templates to use theme colors
2. Replace generic Tailwind classes (blue-500) with custom classes
3. Add gradient utilities (ocean-gradient, sand-gradient, sunset-gradient)
4. Create color-consistent buttons, badges, cards

---

### Phase 2: Coastal Design Elements (Medium Priority)

**Priority:** MEDIUM | **Time:** 3-4 hours

#### A. Wave Dividers & Decorative Elements
**Actions:**
1. Create SVG wave divider component
2. Add to section transitions (hero → features, features → CTA)
3. Implement subtle beach texture backgrounds
4. Add lighthouse/boat/coastal icons for features

**Example SVG Wave:**
```erb
<div class="wave-divider">
  <svg viewBox="0 0 1200 120" preserveAspectRatio="none">
    <path d="M321.39,56.44c58-10.79,114.16-30.13,172-41.86..." 
          fill="currentColor"/>
  </svg>
</div>
```

#### B. Property Cards Redesign
**Current:** Standard cards with shadow  
**Target:** Coastal-themed property cards

**Actions:**
1. Add subtle wave pattern to card tops
2. Implement amber accent border
3. Add hover lift effect with shadow transition
4. Use coastal color badges for property features
5. Rounded corners matching theme (12px)

#### C. Hero Section Variations
**Actions:**
1. Create 3 hero variants:
   - **Hero Centered:** Full-width image with ocean overlay
   - **Hero Split:** Image + search form with wave divider
   - **Hero Search:** Integrated search with coastal gradient
2. Add parallax effect for coastal vibe
3. Implement elegant CTAs with wave underlines

---

### Phase 3: Component Library (Lower Priority)

**Priority:** LOW | **Time:** 4-6 hours

#### A. Custom Biarritz Components

1. **Coastal Stats Counter**
   - Numbers with ocean blue text
   - Wave animation on scroll
   - Sand-colored background sections

2. **Testimonial Carousel**
   - Elegant card design with quotes
   - Avatar with coastal border
   - Smooth carousel with beach-themed indicators

3. **CTA Sections**
   - Ocean gradient backgrounds
   - Wave dividers
   - Elegant buttons with hover effects

4. **Feature Grid**
   - Icons with coastal colors
   - Card hover effects (lift + shadow)
   - Wave decorations

#### B. Footer Redesign
**Current:** Generic footer  
**Target:** Elegant coastal footer

**Actions:**
1. Dark ocean blue background (`#082F49`)
2. Wave pattern at top border
3. Multi-column layout with coastal icons
4. Social media links with hover effects
5. Copyright section with subtle sand color

---

### Phase 4: Advanced Enhancements (Optional)

**Priority:** OPTIONAL | **Time:** 3-4 hours

#### A. Animations & Micro-interactions
1. Fade-in on scroll for sections
2. Wave animation for dividers
3. Smooth hover transitions
4. Loading states with coastal theme

#### B. Dark Mode Variant
1. Define dark ocean palette
2. Implement toggle
3. Preserve coastal feel in dark mode

#### C. Custom Search Experience
1. Elegant search form with coastal styling
2. Animated dropdowns
3. Wave-themed result cards

---

## Implementation Checklist

### Files to Modify

#### Templates (ERB)
- [ ] `_header.html.erb` - Complete redesign
- [ ] `_footer.html.erb` - Coastal styling
- [ ] `welcome/index.html.erb` - Hero + sections
- [ ] `welcome/_single_property_row.html.erb` - Property cards
- [ ] `search/buy.html.erb` - Search page
- [ ] `search/rent.html.erb` - Search page
- [ ] `props/show.html.erb` - Property detail
- [ ] `components/_generic_page_part.html.erb` - Page parts

#### Styles (CSS/Tailwind)
- [ ] `tailwind-biarritz.css` - Expand utilities
- [ ] `custom_css/_biarritz.css.erb` - Add more variables

#### Assets
- [ ] Wave SVG graphics
- [ ] Coastal pattern backgrounds
- [ ] Custom icons (optional)

---

## Quick Start: 1-Hour MVP

**Goal:** Make it look noticeably better in 1 hour

### Priority Actions:
1. **Header** (20 min)
   - Apply ocean gradient
   - Add amber accent border
   - Use Playfair Display for logo
   - Style navigation with coastal colors

2. **Property Cards** (15 min)
   - Add amber top border
   - Apply rounded corners
   - Ocean blue price tags
   - Hover lift effect

3. **Buttons/CTAs** (10 min)
   - Ocean blue primary buttons
   - Amber secondary buttons
   - Add hover transitions

4. **Typography** (10 min)
   - Apply Playfair Display to h1, h2, h3
   - Ensure consistent font usage

5. **Footer** (5 min)
   - Dark ocean background
   - Amber accents
   - Wave top border

---

## Color Usage Guide

### When to Use Each Color:

**Deep Ocean Blue (#0C4A6E):**
- Primary buttons
- Headers/navigation background
- Links
- Section headings
- Footer background (darker variant)

**Warm Amber (#D97706):**
- Secondary buttons
- Accent borders
- Hover states
- Icons
- Price tags
- Active states

**Golden Sunset (#FBBF24):**
- Highlights
- Badges
- Special offers
- Success states
- Decorative elements

**Warm Grays (#FAFAF9, #F5F5F4):**
- Backgrounds
- Section dividers
- Card backgrounds
- Subtle textures

---

## Inspiration Sources

### Visual Style:
- French Basque coastal architecture
- Biarritz beach aesthetic (elegant, upscale)
- Mediterranean luxury real estate sites
- Ocean wave patterns and textures

### Reference Themes to Study:
- Barcelona theme (structure, modern feel)
- Brisbane theme (elegant typography)
- High-end hotel websites (coastal properties)

---

## Success Metrics

### Visual Quality:
- [ ] Distinctive from default theme
- [ ] Coastal identity clearly visible
- [ ] Professional, elegant appearance
- [ ] Consistent color usage throughout
- [ ] Typography hierarchy clear

### Technical:
- [ ] All templates render without errors
- [ ] Responsive on mobile/tablet/desktop
- [ ] Fast page load times
- [ ] Accessible (WCAG AA minimum)

### User Experience:
- [ ] Navigation intuitive
- [ ] CTAs clearly visible
- [ ] Property cards appealing
- [ ] Search forms easy to use

---

## Next Steps

1. **Decision:** Choose improvement scope
   - Quick MVP (1 hour)?
   - Phase 1 only (2-3 hours)?
   - Complete overhaul (8-12 hours)?

2. **Review:** Current Barcelona/Brisbane themes for best practices

3. **Design:** Create coastal components incrementally

4. **Test:** Check each page after changes

5. **Iterate:** Refine based on visual feedback

---

## Notes

- Start with high-impact, low-effort changes (header, colors, typography)
- Test on real property data to ensure cards look good
- Consider creating a style guide after Phase 1
- Document custom components for future themes
