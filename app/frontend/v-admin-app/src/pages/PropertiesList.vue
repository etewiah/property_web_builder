<template>
  <div>
    <!-- <div v-for="property in properties" :key="property.id">
      <div>{{ property.attributes.reference }}</div>
    </div> -->
    <div class="q-pa-md">
      <q-table
        title="All properties"
        :rows="properties"
        :columns="columns"
        row-key="name"
      >
        <template v-slot:body="props">
          <q-tr @click="goToProp(props.row)" :props="props">
            <q-td key="ref" :props="props">
              {{ props.row.attributes.reference }}
            </q-td>
            <q-td key="beds" :props="props">
              {{ props.row.attributes["count-bedrooms"] }}
            </q-td>
            <q-td key="baths" :props="props">
              {{ props.row.attributes["count-bathrooms"] }}
            </q-td>
            <q-td key="visible" :props="props">
              {{ props.row.attributes["visible"] }}
            </q-td>
          </q-tr>
        </template>
      </q-table>
    </div>
  </div>
</template>

<script>
const columns = [
  {
    name: "ref",
    required: true,
    label: "Reference",
    align: "left",
    field: (row) => row.name,
    format: (val) => `${val}`,
    sortable: true,
  },
  {
    name: "beds",
    required: true,
    label: "Bedrooms",
    align: "left",
    field: (row) => row.name,
    format: (val) => `${val}`,
    sortable: true,
  },
  {
    name: "baths",
    required: true,
    label: "Bathrooms",
    align: "left",
    field: (row) => row.name,
    format: (val) => `${val}`,
    sortable: true,
  },
  {
    name: "visible",
    required: true,
    label: "Visible",
    align: "left",
    field: (row) => row.name,
    format: (val) => `${val}`,
    sortable: true,
  },
]
import useProperties from "../compose/useProperties.js"
export default {
  components: {},
  methods: {
    goToProp(propertyRow) {
      let targetRoute = {
        name: "rPropertyEdit",
        params: {
          prop_id: propertyRow.id,
        },
      }
      this.$router.push(targetRoute)
    },
  },
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
      columns,
      getProperties,
    }
  },
  data() {
    return {
      properties: [],
    }
  },
}
</script>
<style></style>
