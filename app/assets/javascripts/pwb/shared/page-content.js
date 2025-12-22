// =============================================================================
// DEPRECATED: Vue component with jQuery dependency
// =============================================================================
// This file is deprecated. Use Stimulus controllers or server-rendered templates.
// See: docs/frontend/STIMULUS_GUIDE.md
// =============================================================================

var INMOAPP = INMOAPP || {};

INMOAPP.PageContent = Vue.component('page-content', {
  mounted: function() {
    console.warn('[DEPRECATED] page-content Vue component - use Stimulus controllers instead');
  },
  props: {
    pageTitle: String
  },
  methods: {
    toggleSidenav() {
      this.$root.toggleSidenav();
    }
  },
  mounted() {
    document.title = this.pageTitle + ' - PropertyWebBuilder';
  }
});
