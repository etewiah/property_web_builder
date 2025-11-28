Vue.component('slick-carousel', {

  mounted: function() {
    var vm = this;
    // 
    $(this.$el).css('visibility','visible').fadeIn(100);;
    $(this.$el).slick(this.slickOptions);
  },
  props: ['slickOptions'],
});
