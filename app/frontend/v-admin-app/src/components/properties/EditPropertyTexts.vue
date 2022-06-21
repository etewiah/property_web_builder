<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
          <div>Texts edit</div>
          <EditAttributesForm
            :currentProperty="currentProperty"
          ></EditAttributesForm>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>
<script>
import EditAttributesForm from "~/v-admin-app/src/components/editor-forms/EditAttributesForm.vue"
export default {
  components: {
    EditAttributesForm,
  },
  methods: {
    // goToProp(propertyRow) {
    //   let targetRoute = {}
    //   this.$router.push(targetRoute)
    // },
  },
  props: {
    currentProperty: {
      type: Object,
      default: () => {},
    },
  },
  mounted: function () {
    // this.getProperties()
    //   .then((response) => {
    //     this.properties = response.data.data
    //   })
    //   .catch((error) => {})
  },
  setup(props) {
    // const { getProperties } = useProperties()
    // return {
    //   getProperties,
    // }
  },
  data() {
    return {
      // currentProperty: {},
      // activeTab: null,
      // properties: [],
    }
  },
}
</script>
<style></style>
