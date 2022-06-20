<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
          <div>Texts edit</div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>
<script>
// import useProperties from "../compose/useProperties.js"
export default {
  components: {},
  methods: {
    // goToProp(propertyRow) {
    //   let targetRoute = {}
    //   this.$router.push(targetRoute)
    // },
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
