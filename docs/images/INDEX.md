# Image Processing Documentation

This folder contains documentation for PropertyWebBuilder's image handling system, including both current architecture and future mobile optimization plans.

## Current State (How It Works Today)

| Document | Description |
|----------|-------------|
| [CURRENT_ARCHITECTURE.md](CURRENT_ARCHITECTURE.md) | Current image handling system overview |
| [DATA_FLOW.md](DATA_FLOW.md) | Visual diagrams of image processing flows |
| [EXAMPLES.md](EXAMPLES.md) | Working code examples for current system |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Quick reference for current helpers |

## CDN & Hosting Configuration

| Document | Description |
|----------|-------------|
| [CDN_HOSTING_IMPROVEMENT_PLAN.md](CDN_HOSTING_IMPROVEMENT_PLAN.md) | Environment variable naming, CDN URL fixes, and test specs |

## Future State (Mobile Optimization Plan)

| Document | Description |
|----------|-------------|
| [MOBILE_OPTIMIZATION_SPEC.md](MOBILE_OPTIMIZATION_SPEC.md) | Technical specification for mobile-optimized images |
| [RESPONSIVE_VARIANTS.md](RESPONSIVE_VARIANTS.md) | Breakpoint and variant definitions |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Step-by-step implementation guide |
| [HELPER_API.md](HELPER_API.md) | API reference for new responsive helpers |

## Quick Links

### For Developers
- [Implementation Guide](IMPLEMENTATION_GUIDE.md) - Start here for implementation
- [Helper API](HELPER_API.md) - Reference for view helpers

### For Architects
- [Technical Specification](MOBILE_OPTIMIZATION_SPEC.md) - Full specification
- [Variant Definitions](RESPONSIVE_VARIANTS.md) - Breakpoints and sizes

## Current vs Proposed

| Feature | Current | Proposed |
|---------|---------|----------|
| Responsive images | Manual sizes | Automatic srcset |
| Format | WebP (manual) | WebP + AVIF (auto) |
| Variant generation | On-demand | Pre-generated |
| Mobile optimization | None | Breakpoint-specific |
| Art direction | None | Crop presets |
