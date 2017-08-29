var INMOAPP = INMOAPP || {};
Vue.component('squares-container', {
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
  // props: ['selectOptions', 'selectPickerTexts', 'selected'],
  watch: {
    props(val) {
      val.forEach(function(prop){
        prop.url = "/tabs/" + prop[".key"];
      });
      // debugger;
      // let total = this.events.length;
    },
  },
  firebase: function() {
    return {
      props: {
        source: INMOAPP.fbDb.ref('props/pwb1'),
        // asObject: true,
        // Optional, allows you to handle any errors.
        cancelCallback(err) {
          debugger;
          console.error(err);
        }
      }
    }
  },
  data: () => {
    return {
      props: [],
      percentage: 0,
      events: {},
    }
  },
  methods: {
    // toggleLeftSidenav() {
    //   this.$refs.leftSidenav.toggle();
    // },
    // toggleRightSidenav() {
    //   this.$refs.rightSidenav.toggle();
    // },
    // closeRightSidenav() {
    //   this.$refs.rightSidenav.close();
    // },
    // open(ref) {
    //   console.log('Opened: ' + ref);
    // },
    // close(ref) {
    //   console.log('Closed: ' + ref);
    // }
  }
});
