<template>
  <div>
    <div class="q-pa-md">
      <q-card class="property-edit-card">
        <q-card-section>
          <div>Page edit</div>
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
                    name: 'rPagesEditTab',
                    params: { pageTabName: 'title' },
                  }"
                  name="edit-title"
                  label="Title"
                  :exact="true"
                />
                <q-route-tab
                  v-for="routeTab in routeTabs"
                  :key="routeTab.page_part_key"
                  :to="{
                    name: 'rPagesEditTab',
                    params: { pageTabName: routeTab.page_part_key },
                  }"
                  :name="`edit-name-${routeTab.page_part_key}`"
                  :label="routeTab.page_part_key"
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
                <q-tab-panel class="q-px-xs" name="edit-title">
                  <router-view :pageTabDetails="{ editor_setup: {} }" />
                </q-tab-panel>
                <q-tab-panel
                  v-for="routeTab in routeTabs"
                  :key="routeTab.page_part_key"
                  class="q-px-none"
                  :name="`edit-name-${routeTab.page_part_key}`"
                >
                  <router-view :pageTabDetails="routeTab" />
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
import usePages from "~/v-admin-app/src/compose/usePages.js"
export default {
  components: {},
  methods: {},
  computed: {
    routeTabs() {
      let routeTabs = []
      if (this.currentPage.page_parts) {
        routeTabs = this.currentPage.page_parts
        // this.currentPage.page_parts.forEach((pagePart) => {

        // })
      }
      return routeTabs
    },
  },
  watch: {
    "$route.params.pageName": {
      handler(newValue, oldVal) {
        this.getPage(newValue)
          .then((response) => {
            this.currentPage = response.data
          })
          .catch((error) => {})
      },
      // deep: true,
      immediate: true,
    },
  },
  mounted: function () {},
  setup(props) {
    const { getPage } = usePages()
    return {
      getPage,
    }
  },
  data() {
    return {
      currentPage: {},
      activeTab: null,
    }
  },
}
</script>
<style></style>
