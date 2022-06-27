<template>
  <div>
    <div class="q-pa-md">
      <div
        v-if="pagePartDetails.page_part_key === 'title'"
        class="row q-col-gutter-md"
      >
        <div
          class="col-12"
          v-for="supportedLocale in websiteProvider.supportedLocaleDetails.full"
          :key="supportedLocale.localeOnly"
        >
          <div class="text-subtitle1">{{ supportedLocale.label }}</div>
          <TextField
            :cancelPendingChanges="cancelPendingChanges"
            :fieldDetails="{
              fieldName: `page_title_${supportedLocale.localeOnly}`,
            }"
            :currentFieldValue="
              currentPage[`page_title_${supportedLocale.localeOnly}`]
            "
            v-on:updatePendingChanges="updatePendingChanges"
          ></TextField>
        </div>
        <div class="row">
          <div class="col-12">
            <GenericSubmitter
              :cancelPendingChanges="cancelPendingChanges"
              :lastChangedField="lastChangedField"
              :currentModelForEditing="currentPage"
              @changesCanceled="changesCanceled"
              @runModelUpdate="runModelUpdate"
            ></GenericSubmitter>
          </div>
        </div>
      </div>
      <div v-else class="row q-col-gutter-md">
        <div class="text-center full-width">
          <div class="">
            <span class="text-subtitle1">Visible On Page:</span>
            <q-toggle
              :label="tabPageContentItem.visible_on_page ? 'Yes' : 'No'"
              v-model="tabPageContentItem.visible_on_page"
              color="green"
              @update:model-value="toggleVisibility"
            />
          </div>
        </div>
        <div
          class="col-12"
          v-for="supportedLocale in websiteProvider.supportedLocaleDetails.full"
          :key="supportedLocale.localeOnly"
        >
          <EditPageTabLocaleItem
            :supportedLocale="supportedLocale"
            :pageContents="pageContents"
            :pagePartDetails="pagePartDetails"
            :tabPageContentItem="tabPageContentItem"
          ></EditPageTabLocaleItem>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import usePages from "~/v-admin-app/src/compose/usePages.js"
import GenericSubmitter from "~/v-admin-app/src/components/editor-forms-parts/GenericSubmitter.vue"
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
// import EditPageBlocks from "~/v-admin-app/src/components/pages/EditPageBlocks.vue"
import EditPageTabLocaleItem from "~/v-admin-app/src/components/pages/EditPageTabLocaleItem.vue"
import loFind from "lodash/find"
export default {
  inject: ["websiteProvider"],
  components: {
    EditPageTabLocaleItem,
    GenericSubmitter,
    // EditPageBlocks,
    TextField,
  },
  computed: {
    tabPageContentItem() {
      let pageContentItem = {}
      let pageTabName = this.$route.params.pageTabName
      pageContentItem = loFind(this.pageContents, function (pc) {
        return pc["content_page_part_key"] === pageTabName
      })
      return pageContentItem ? pageContentItem : { visible_on_page: true }
    },
  },
  setup() {
    const { updatePage, updatePagePartVisibility } = usePages()
    return {
      updatePage,
      updatePagePartVisibility,
    }
  },
  methods: {
    // setEditMode() {
    //   this.showPreview = false
    // },
    toggleVisibility(newVisibility) {
      this.tabPageContentItem.visible_on_page = newVisibility
      let pageSlug = this.$route.params.pageName
      let pagePartKey = this.$route.params.pageTabName
      this.updatePagePartVisibility(pageSlug, pagePartKey, newVisibility)
        .then((response) => {
          this.$q.notify({
            color: "green-4",
            textColor: "white",
            icon: "cloud_done",
            message: "Visibility updated successfully",
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
    runModelUpdate(currPendingChanges) {
      currPendingChanges["slug"] = this.$route.params.pageName
      this.updatePage(currPendingChanges)
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
    updatePendingChanges({ fieldDetails, newValue }) {
      fieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = fieldDetails
      // In some cases (like here) I need to set lastUpdateStamp
      // to trigger watcher in form submitter
      this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      // this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  props: {
    currentPage: {
      type: Object,
      default() {
        return {}
      },
    },
    pageContents: {},
    pagePartDetails: {},
  },
  data() {
    return {
      // showPreview: true,
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
      },
    }
  },
}
</script>
<style></style>
