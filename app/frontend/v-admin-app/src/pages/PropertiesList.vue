<template>
  <div>
    <h1>properties...</h1>
    <div v-for="property in properties" :key="property.id">
      <div>{{ property.attributes.reference }}</div>
    </div>
  </div>
</template>
<script>
import useProperties from "../compose/useProperties.js";
export default {
  components: {},
  mounted: function () {
    this.getProperties()
      .then((response) => {
        this.properties = response.data.data
      })
      .catch((error) => {})
  },
  setup(props) {
    const { getProperties } = useProperties()
    return {
      getProperties,
    };
  },
  data() {
    return {
      // topListing: {},
      // bottomListing: {},
      properties: [],
    };
  },
};
</script>
<style></style>
