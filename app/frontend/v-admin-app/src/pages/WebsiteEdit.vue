<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
          <div>
            Website Settings for {{ currentWebsite.company_display_name }}
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
                  :to="{ name: 'rWebsiteEditGeneral' }"
                  name="edit-general"
                  label="General"
                  :exact="true"
                />
                <q-route-tab
                  name="edit-appearance"
                  label="Appearance"
                  :to="{ name: 'rWebsiteEditAppearance' }"
                  :exact="true"
                />
                <q-route-tab
                  name="edit-navigation"
                  label="Navigation"
                  :to="{ name: 'rWebsiteEditNavigation' }"
                  :exact="true"
                />
                <q-route-tab
                  name="edit-home"
                  label="Home"
                  :to="{ name: 'rWebsiteEditHome' }"
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
                  <router-view :currentWebsite="currentWebsite" />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-appearance">
                  <router-view :currentWebsite="currentWebsite" />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-navigation">
                  <router-view :currentWebsite="currentWebsite" />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-home">
                  <router-view :currentWebsite="currentWebsite" />
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
// import useAgency from "~/v-admin-app/src/compose/useAgency.js"
export default {
  components: {},
  props: {
    currentWebsite: {
      type: Object,
      default: () => {},
    },
  },
  data() {
    return {
      // currentWebsite: {
      //   attributes: {},
      // },
      activeTab: null,
    }
  },
}
</script>
<style></style>
