<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
          <div>
            Agency Settings for {{ currentAgency.company_display_name }}
          </div>
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
                  :to="{ name: 'rAgencyEditGeneral' }"
                  name="edit-general"
                  label="General"
                  :exact="true"
                />
                <q-route-tab
                  name="edit-location"
                  label="Location"
                  :to="{ name: 'rAgencyEditLocation' }"
                  :exact="true"
                />
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
                  <router-view :currentAgency="currentAgency" />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-location">
                  <router-view :currentAgency="currentAgency" />
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
import useAgency from "~/v-admin-app/src/compose/useAgency.js"
export default {
  components: {},
  methods: {},
  mounted: function () {
    this.getAgency()
      .then((response) => {
        this.currentAgency = response.data.agency
      })
      .catch((error) => {})
  },
  setup(props) {
    const { getAgency } = useAgency()
    return {
      getAgency,
    }
  },
  data() {
    return {
      // propertyFound: true,
      // authorizedToViewProperty: true,
      currentAgency: {
        attributes: {},
      },
      activeTab: null,
      // properties: [],
    }
  },
}
</script>
<style></style>
