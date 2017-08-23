Vue.component('select-picker', {
  template: '<select class="" >' +
    '<option  v-for="option in selectOptions">{{ option }}</option>' +
    '</select>',
  mounted: function() {
    var vm = this;
    $(this.$el).selectpicker(this.selectPickerTexts);
    // .trigger('change')
    // // emit event on change.
    // .on('change', function() {
    //   vm.$emit('input', this.value)
    // });
  },
  props: ['selectOptions', 'selectPickerTexts', 'selected'],
});
