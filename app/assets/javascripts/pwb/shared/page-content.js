var INMOAPP = INMOAPP || {};
INMOAPP.PageContent = Vue.component('page-content', {
  // name: "SquaresContainer",
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
