// =============================================================================
// DEPRECATED: Slick Carousel Vue component
// =============================================================================
// This file is deprecated. Use the Stimulus gallery_controller.js instead.
// See: app/javascript/controllers/gallery_controller.js
// See: docs/frontend/STIMULUS_GUIDE.md
// =============================================================================

Vue.component('slick-carousel', {
  mounted: function() {
    console.warn('[DEPRECATED] slick-carousel Vue component - use gallery_controller.js instead');
    var vm = this;
    // jQuery-based Slick initialization
    if (typeof $ !== 'undefined' && typeof $.fn.slick !== 'undefined') {
      $(this.$el).css('visibility','visible').fadeIn(100);
      $(this.$el).slick(this.slickOptions);
    } else {
      // Fallback: just show the element
      this.$el.style.visibility = 'visible';
    }
  },
  props: ['slickOptions'],
});
