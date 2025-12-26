# Image Processing Documentation

This folder contains documentation for PropertyWebBuilder's image handling system, including the mobile optimization specification.

## Documents

| Document | Description |
|----------|-------------|
| [MOBILE_OPTIMIZATION_SPEC.md](MOBILE_OPTIMIZATION_SPEC.md) | Technical specification for mobile-optimized images |
| [RESPONSIVE_VARIANTS.md](RESPONSIVE_VARIANTS.md) | Breakpoint and variant definitions |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Step-by-step implementation guide |
| [HELPER_API.md](HELPER_API.md) | API reference for image helpers |

## Related Documentation

- [Image Handling Architecture](../image_handling_architecture.md) - Current system overview
- [Image Handling Examples](../image_handling_examples.md) - Code examples
- [Image Handling Data Flow](../image_handling_data_flow.md) - Flow diagrams

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
