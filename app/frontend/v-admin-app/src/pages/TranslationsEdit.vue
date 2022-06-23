<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
          <!-- <div>Translations</div> -->
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
                  :to="{
                    name: 'rTranslationsEditBatch',
                    params: { tBatchId: 'extras' },
                  }"
                  name="edit-features"
                  label="Features"
                  :exact="true"
                />
                <q-route-tab
                  :to="{
                    name: 'rTranslationsEditBatch',
                    params: { tBatchId: 'property-types' },
                  }"
                  name="edit-prop-types"
                  label="Property Types"
                  :exact="true"
                />
                <q-route-tab
                  :to="{
                    name: 'rTranslationsEditBatch',
                    params: { tBatchId: 'property-states' },
                  }"
                  name="edit-prop-states"
                  label="Property States"
                  :exact="true"
                />
                <q-route-tab
                  :to="{
                    name: 'rTranslationsEditBatch',
                    params: { tBatchId: 'property-labels' },
                  }"
                  name="edit-prop-labels"
                  label="Property Labels"
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
                <q-tab-panel class="q-px-xs" name="edit-features">
                  <router-view />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-prop-types">
                  <router-view />
                </q-tab-panel>
                <q-tab-panel class="q-px-xs" name="edit-prop-states">
                  <router-view />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-prop-labels">
                  <router-view />
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
// import useTranslations from "~/v-admin-app/src/compose/useTranslations.js"
export default {
  components: {},
  methods: {},
  // mounted: function () {
  //   let batchName = "extras"
  //   this.getTranslations(batchName)
  //     .then((response) => {
  //       this.translationsBatch = response.data.translations
  //     })
  //     .catch((error) => {})
  // },
  // setup(props) {
  //   const { getTranslations } = useTranslations()
  //   return {
  //     getTranslations,
  //   }
  // },
  data() {
    return {
      // translationsBatch: [],
      activeTab: null,
    }
  },
}
</script>
<style></style>
