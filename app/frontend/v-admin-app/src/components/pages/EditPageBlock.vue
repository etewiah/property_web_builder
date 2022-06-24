<template>
  <div>
    <div v-if="editorBlockItem.isHtml || editorBlockItem.isMultipleLineText">
      <HtmlField
        :cancelPendingChanges="cancelPendingChanges"
        :fieldDetails="editorBlockItemFieldDetails"
        :currentFieldValue="blockValue"
        v-on:updatePendingChanges="updatePendingChanges"
      ></HtmlField>
    </div>
    <div v-else-if="editorBlockItem.isSingleLineText">
      <TextField
        :cancelPendingChanges="cancelPendingChanges"
        :fieldDetails="editorBlockItemFieldDetails"
        :currentFieldValue="blockValue"
        v-on:updatePendingChanges="updatePendingChanges"
      ></TextField>
    </div>
    <div v-else>
      {{ blockValue }}
    </div>
    <div class="row">
      <div class="col-12">
        <GenericSubmitter
          :cancelPendingChanges="cancelPendingChanges"
          :lastChangedField="lastChangedField"
          :currentModelForEditing="
            pageTabDetails.block_contents[editorLocale].blocks[
              editorBlockItem.label
            ]
          "
          @changesCanceled="changesCanceled"
          @runModelUpdate="runModelUpdate"
        ></GenericSubmitter>
      </div>
    </div>
  </div>
</template>
<script>
import usePages from "~/v-admin-app/src/compose/usePages.js"
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
import HtmlField from "~/v-admin-app/src/components/editor-forms-parts/HtmlField.vue"
import GenericSubmitter from "~/v-admin-app/src/components/editor-forms-parts/GenericSubmitter.vue"
export default {
  components: {
    TextField,
    HtmlField,
    GenericSubmitter,
  },
  computed: {
    blockValue() {
      let block =
        this.pageTabDetails.block_contents[this.editorLocale].blocks[
          this.editorBlockItem.label
        ] || {}
      return block.content || ""
    },
    editorBlockItemFieldDetails() {
      let qInputType = ""
      if (this.editorBlockItem.isMultipleLineText) {
        qInputType = "textarea"
      }
      if (this.editorBlockItem.isSingleLineText) {
        qInputType = "text"
      }
      return {
        qInputType: qInputType,
        fieldName: "content", // this.editorBlockItem.label
      }
    },
  },
  methods: {
    changesCanceled() {
      this.cancelPendingChanges = true
    },
    runModelUpdate(currPendingChanges) {
      let fragmentDetails = {
        page_part_key: this.$route.params.pageTabName,
        locale: this.editorLocale,
        blocks: {
          // main_content: {
          //   content: "...",
          // },
        },
      }
      let pageSlug = this.$route.params.pageName
      fragmentDetails.blocks[this.editorBlockItem.label] = {
        content: currPendingChanges.content,
      }
      this.updatePageFragment(pageSlug, fragmentDetails)
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
      // fieldDetails.batch_key = "extras"
      this.lastChangedField.fieldDetails = fieldDetails
      this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
      // this.$emit("updatePendingChanges", {
      //   fieldDetails: fieldDetails,
      //   newValue: newValue,
      // })
    },
  },
  props: {
    pageTabDetails: {},
    editorBlockItem: {},
    editorLocale: {},
  },
  // mounted: function () {
  //   let batchName = this.$route.params.tBatchId
  //   // "extras"
  //   this.updatePageFragment(batchName)
  //     .then((response) => {
  //       this.translationsBatch = response.data.translations
  //     })
  //     .catch((error) => {})
  // },
  setup(props) {
    const { updatePageFragment } = usePages()
    return {
      updatePageFragment,
    }
  },
  data() {
    return {
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {
          newValue: "",
        },
        lastUpdateStamp: "",
      },
    }
  },
}
</script>
<style></style>
