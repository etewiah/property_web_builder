<template>
  <div>
    <div class="q-pa-md">
      <!-- <div>Navigation</div> -->
      <div class="row">
        <div class="col-3">
          <div class="q-mb-md text-h6 nav-group-label">Top Navigation</div>
          <div
            v-for="navLink in currentNavLinks.top_nav_links"
            :key="navLink.slug"
          >
            <div>{{ navLink.link_title }}</div>
            <ToggleField
              :cancelPendingChanges="cancelPendingChanges"
              :fieldDetails="navLink"
              v-on:updatePendingChanges="updatePendingChanges"
            ></ToggleField>
          </div>
        </div>
        <div class="col-3">
          <div class="q-mb-md text-h6 nav-group-label">Footer Navigation</div>
          <div
            v-for="navLink in currentNavLinks.footer_links"
            :key="navLink.slug"
          >
            <div>{{ navLink.link_title }}</div>
            <ToggleField
              :cancelPendingChanges="cancelPendingChanges"
              :fieldDetails="navLink"
              v-on:updatePendingChanges="updatePendingChanges"
            ></ToggleField>
          </div>
        </div>
      </div>
      <div class="row">
        <div class="col-12">
          <LinksSubmitter
            :cancelPendingChanges="cancelPendingChanges"
            :lastChangedField="lastChangedField"
            :currentModelForEditing="currentNavLinks"
            @changesCanceled="changesCanceled"
            @runModelUpdate="runModelUpdate"
          ></LinksSubmitter>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
// import { defineComponent, ref } from "vue"
import ToggleField from "~/v-admin-app/src/components/editor-forms-parts/ToggleField.vue"
import LinksSubmitter from "~/v-admin-app/src/components/editor-forms-parts/LinksSubmitter.vue"
import useLinks from "~/v-admin-app/src/compose/useLinks.js"
export default {
  components: {
    LinksSubmitter,
    ToggleField,
  },
  methods: {
    runModelUpdate(currPendingChanges) {
      this.updateLinks(this.currentNavLinks)
        .then((response) => {
          // location.reload()
          // this.currPendingChanges = {}
          this.$q.notify({
            color: "green-4",
            textColor: "white",
            icon: "cloud_done",
            message: "Updated successfully",
          })
        })
        .catch((error) => {
          let errorMessage = error.message || "Sorry, unable to update"
          if (
            error.response.data.errors[0] &&
            error.response.data.errors[0].meta.exception
          ) {
            errorMessage = error.response.data.errors[0].meta.exception
          }
          this.$q.notify({
            color: "red-4",
            textColor: "white",
            icon: "error",
            message: errorMessage,
          })
        })
    },
    updatePendingChanges({ fieldDetails, newValue, navGroup }) {
      let newFieldDetails = {
        fieldName: fieldDetails.slug,
        navGroup: navGroup,
      }
      newFieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = newFieldDetails
      // this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  props: {},
  mounted: function () {
    this.getLinks()
      .then((response) => {
        this.currentNavLinks = response.data
      })
      .catch((error) => {})
  },
  setup(props) {
    const { getLinks, updateLinks } = useLinks()
    return {
      getLinks,
      updateLinks,
    }
  },
  data() {
    return {
      currentNavLinks: {},
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
        // lastUpdateStamp: "",
      },
    }
  },
}
</script>
<style></style>
