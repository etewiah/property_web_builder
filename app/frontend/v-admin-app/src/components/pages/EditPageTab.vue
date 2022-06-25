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
          <div>{{ supportedLocale.label }}</div>
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
        <div
          class="col-12"
          v-for="supportedLocale in websiteProvider.supportedLocaleDetails.full"
          :key="supportedLocale.localeOnly"
        >
          <div>{{ supportedLocale.label }}</div>
          <div>
            <div
              class="raw-display-el"
              v-html="tabPageContents[`raw_${supportedLocale.localeOnly}`]"
            ></div>
          </div>
          <div>
            <EditPageBlocks
              :pagePartDetails="pagePartDetails"
              :editorBlocks="editorBlocks"
              :currentBlockLocale="supportedLocale.localeOnly"
            >
            </EditPageBlocks>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import usePages from "~/v-admin-app/src/compose/usePages.js"
import GenericSubmitter from "~/v-admin-app/src/components/editor-forms-parts/GenericSubmitter.vue"
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
import EditPageBlocks from "~/v-admin-app/src/components/pages/EditPageBlocks.vue"
import loFind from "lodash/find"
export default {
  inject: ["websiteProvider"],
  components: {
    GenericSubmitter,
    EditPageBlocks,
    TextField,
  },
  computed: {
    tabPageContents() {
      let tabPageContents = {}
      let pageTabName = this.$route.params.pageTabName
      tabPageContents = loFind(this.pageContents, function (pc) {
        return pc["content_page_part_key"] === pageTabName
      })
      return tabPageContents ? tabPageContents.content : ""
    },
    editorBlocks() {
      return this.pagePartDetails.editor_setup.editorBlocks
    },
  },
  setup() {
    const { updatePage } = usePages()
    return {
      updatePage,
    }
  },
  methods: {
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
    currentPage: {},
    pageContents: {},
    pagePartDetails: {},
  },
  data() {
    return {
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
      },
    }
  },
}
</script>
<style>
.jumbotron {
  -webkit-text-size-adjust: 100%;
  font-family: roboto;
  font-size: 16px;
  line-height: 1.42857143;
  font-weight: 400;
  box-sizing: border-box;
  -webkit-font-smoothing: antialiased;
  outline: 0 !important;
  -webkit-tap-highlight-color: transparent !important;
  margin-bottom: 30px;
  color: white;
  background-color: #f7f7f7;
  padding: 0;
  border-radius: 2px;
  padding-left: 60px;
  padding-right: 60px;
}
.raw-disp-el {
  -webkit-text-size-adjust: 100%;
  font-family: roboto;
  font-size: 16px;
  line-height: 1.42857143;
  color: #5e5e5e;
  font-weight: 400;
  box-sizing: border-box;
  -webkit-font-smoothing: antialiased;
  outline: 0 !important;
  -webkit-tap-highlight-color: transparent !important;
  border: #d9edf7;
  border-style: dashed;
  border-radius: 10px;
  padding: 25px 0;
}
</style>
