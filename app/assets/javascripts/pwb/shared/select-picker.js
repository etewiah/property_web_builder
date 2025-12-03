Vue.component('select-picker', {
  template: '<select class="" >' +
    '<option  v-for="option in selectOptions">{{ option }}</option>' +
    '</select>',
  mounted: function() {
    var vm = this;
    this.$nextTick(function () {
      if (typeof $(this.$el).selectpicker === 'function') {
        $(this.$el).selectpicker(this.selectPickerTexts);
      } else {
        console.warn('bootstrap-select plugin not found');
      }
    })
    // .trigger('change')
    // // emit event on change.
    // .on('change', function() {
    //   vm.$emit('input', this.value)
    // });
  },
  props: ['selectOptions', 'selectPickerTexts', 'selected'],
});
