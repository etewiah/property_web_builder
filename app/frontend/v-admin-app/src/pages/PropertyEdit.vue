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
                <!-- <q-route-tab
                  :to="{ name: 'rPropertyEditGeneral' }"
                  name="edit-general"
                  label="General"
                  :exact="true"
                />
                <q-route-tab
                  name="edit-texts"
                  label="Texts"
                  :to="{ name: 'rPropertyEditTab' }"
                  :exact="true"
                /> -->
                <q-route-tab
                  v-for="propTab in editPropTabs"
                  :key="propTab.tabValue"
                  :to="{
                    name: propTab.tabRouteName,
                    params: {
                      editTabName: propTab.tabValue,
                    },
                  }"
                  :name="`edit-name-${propTab.tabValue}`"
                  :label="propTab.tabLabel"
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
                <!-- <q-tab-panel class="q-px-xs" name="edit-general">
                  <router-view :currentProperty="currentProperty" />
                </q-tab-panel>
                <q-tab-panel class="q-px-none" name="edit-texts">
                  <router-view :currentProperty="currentProperty" />
                </q-tab-panel> -->

                <q-tab-panel
                  v-for="propTab in editPropTabs"
                  :key="propTab.tabValue"
                  :name="`edit-name-${propTab.tabValue}`"
                  class="q-px-none"
                >
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
  methods: {},
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
      editPropTabs: [
        {
          tabValue: "general",
          tabLabel: "general",
          tabRouteName: "rPropertyEditTab",
          tabTitleKey: "propertySections.general",
        },
        {
          tabValue: "text",
          tabLabel: "text",
          tabRouteName: "rPropertyEditTab",
          tabTitleKey: "propertySections.text",
        },
        {
          tabValue: "sale-rental",
          tabLabel: "Sale / Rental",
          tabRouteName: "rPropertyEditTab",
          tabTitleKey: "propertySections.sale",
        },
        {
          tabValue: "location",
          tabLabel: "Location",
          tabRouteName: "rPropertyEditTab",
          tabTitleKey: "propertySections.location",
        },
        {
          tabValue: "features",
          tabLabel: "Features",
          tabRouteName: "rPropertyEditTab",
          tabTitleKey: "propertySections.extras",
        },
        {
          tabValue: "photos",
          tabLabel: "Photos",
          tabRouteName: "rPropertyEditTab",
          tabTitleKey: "propertySections.photos",
        },
        {
          tabValue: "owner",
          tabLabel: "Owner",
          tabRouteName: "rPropertyEditTab",
          tabTitleKey: "propertySections.owner",
        },
      ],
      currentProperty: {
        attributes: {},
      },
      activeTab: null,
    }
  },
}
</script>
<style></style>
