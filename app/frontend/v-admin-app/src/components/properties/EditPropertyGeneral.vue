<template>
  <div class="property-edit-ctr">
    <div class="q-pa-md">
      <component
        :is="editTabComponent"
        :currentProperty="currentProperty"
      ></component>
      <!-- <EditAttributesForm
            :currentProperty="currentProperty"
          ></EditAttributesForm> -->
    </div>
  </div>
</template>
<script>
import EditAttributesForm from "~/v-admin-app/src/components/editor-forms/EditAttributesForm.vue"
import PropertyTextsForm from "~/v-admin-app/src/components/editor-forms/PropertyTextsForm.vue"
import ImageManager from "~/v-admin-app/src/components/editor-forms-parts/ImageManager.vue"
export default {
  components: {
    EditAttributesForm,
    PropertyTextsForm,
    ImageManager
  },
  computed: {
    editTabComponent() {
      let editTabComponent = "EditAttributesForm"
      if (this.$route.params.editTabName === "text") {
        editTabComponent = "PropertyTextsForm"
      }
      if (this.$route.params.editTabName === "photos") {
        editTabComponent = "ImageManager"
      }
      return editTabComponent
    },
  },
  props: {
    currentProperty: {
      type: Object,
      default: () => {},
    },
  },
  mounted: function () {},
  setup(props) {},
  data() {
    return {}
  },
}
</script>
<style></style>
