var INMOAPP = INMOAPP || {};
INMOAPP.TabableSection = Vue.component('tabable-section', {
  template: `<div class="main-content component-docs">` +
    `<md-tabs md-fixed class="md-transparent">` +
    `<md-tab id="movies" md-label="Movies">Some content` +
    `</md-tab>` +
    `<md-tab id="shops" md-label="Shp">shop  content` +
    `</md-tab></md-tabs>` +
    `</div>`,
  watch: {
    listing(val) {
      // debugger;
      // val.forEach(function(prop){
      //   prop.url = "/tabs/" + prop[".key"];
      // });
    },
  },
  firebase: function() {
    return {
      listing: {
        source: INMOAPP.fbDb.ref('listing/pwb1/' + this.$route.params.id),
        // asObject: true,
        // Optional, allows you to handle any errors.
        cancelCallback(err) {
          // debugger;
          console.error(err);
        }
      }
    }
  },
  data: () => {
    return {
      listing: []
    }
  },
  // props: {
  //   pageTitle: String
  // },
  methods: {
    toggleSidenav() {
      this.$root.toggleSidenav();
    }
  },
  mounted() {
    // document.title = this.pageTitle + ' - Vue Material';
  }
});
