<template>
  <div class="property-edit-ctr">
    <div class="q-pa-md">
      <component
        :key="currentProperty.id"
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
import PropertyLocationForm from "~/v-admin-app/src/components/editor-forms/PropertyLocationForm.vue"
import PropertyOwnerForm from "~/v-admin-app/src/components/editor-forms/PropertyOwnerForm.vue"
import ImageManager from "~/v-admin-app/src/components/editor-forms-parts/ImageManager.vue"
export default {
  components: {
    EditAttributesForm,
    PropertyTextsForm,
    PropertyLocationForm,
    PropertyOwnerForm,
    ImageManager,
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
      if (this.$route.params.editTabName === "location") {
        editTabComponent = "PropertyLocationForm"
      }
      if (this.$route.params.editTabName === "owner") {
        editTabComponent = "PropertyOwnerForm"
      }
      return editTabComponent
    },
  },
  props: {
    currentProperty: {
      type: Object,
      default: () => {
        attributes: {
        }
      },
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
