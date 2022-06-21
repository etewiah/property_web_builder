<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
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
  methods: {},
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
