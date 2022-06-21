<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
          <div>Edit "{{ currentProperty.attributes.title }}"</div>
          <div class="col-xs-12 q-mt-md">
            <div class="board-prop-overview-ctr">
              <q-tabs
                dense
                mobile-arrows
                class="text-grey"
                active-color="primary"
                indicator-color="primary"
                align="justify"
                narrow-indicator
                outside-arrows
                v-model="activeTab"
              >
                <q-route-tab
                  :to="{ name: 'rPropertyEditGeneral' }"
                  name="edit-general"
                  label="General"
                  :exact="true"
                />
                <!-- <q-tab name="mortgage" label="Mortgage" /> -->
                <q-route-tab
                  name="edit-texts"
                  label="Texts"
                  :to="{ name: 'rPropertyEditTexts' }"
                  :exact="true"
                />
                <!-- <q-tab name="checklist" label="Checklist" /> -->
                <!-- <q-tab name="distances" label="Distances" /> -->
              </q-tabs>

              <q-separator />

              <q-tab-panels
                transition-next="slide-left"
                transition-duration="1000"
                transition-prev="slide-right"
                :infinite="false"
                v-model="activeTab"
                animated
              >
                <q-tab-panel class="q-px-xs" name="edit-general">
                  <router-view :currentProperty="currentProperty" />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-texts">
                  <router-view :currentProperty="currentProperty" />
                </q-tab-panel>
              </q-tab-panels>
            </div>
          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script>
import useProperties from "../compose/useProperties.js"
export default {
  components: {},
  methods: {
    // goToProp(propertyRow) {
    //   let targetRoute = {
    //   }
    //   this.$router.push(targetRoute)
    // },
  },
  mounted: function () {
    this.getProperty(this.$route.params.prop_id)
      .then((response) => {
        this.currentProperty = response.data.data
      })
      .catch((error) => {})
  },
  setup(props) {
    const { getProperty } = useProperties()
    return {
      getProperty,
    }
  },
  data() {
    return {
      // propertyFound: true,
      // authorizedToViewProperty: true,
      currentProperty: {
        attributes: {},
      },
      activeTab: null,
      // properties: [],
    }
  },
}
</script>
<style></style>
