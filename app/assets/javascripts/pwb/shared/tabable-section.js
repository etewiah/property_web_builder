var INMOAPP = INMOAPP || {};
INMOAPP.TabableSection = Vue.component('tabable-section', {
  template: `<div class="main-content component-docs">` +
    `<md-tabs md-fixed class="md-transparent">` +
    `<md-tab id="movies" md-label="Movies">Some content` +
    `</md-tab>` +
    `<md-tab id="shops" md-label="Shp">shop  content` +
    `</md-tab></md-tabs>` +
    `</div>`,
  mounted: function() {
    // var vm = this;
    // $(this.$el).selectpicker(this.selectPickerTexts);
    // .trigger('change')
    // // emit event on change.
    // .on('change', function() {
    //   vm.$emit('input', this.value)
    // });
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
    document.title = this.pageTitle + ' - Vue Material';
  }
});
