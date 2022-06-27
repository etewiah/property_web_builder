<template>
  <div>
    <q-card>
      <q-card-section
        v-for="editorBlock in editorBlocks"
        :key="editorBlock.nada"
        class="translation-item-card"
      >
        <div
          v-for="editorBlockItem in editorBlock"
          :key="editorBlockItem.label"
        >
          <!-- <div>{{ editorBlockItem.label }}</div> -->
          <PageBlockItem
            :cancelPendingChanges="cancelPendingChanges"
            v-on:updatePendingChanges="updatePendingChanges"
            :pagePartDetails="pagePartDetails"
            :editorBlockItem="editorBlockItem"
            :currentBlockLocale="currentBlockLocale"
          ></PageBlockItem>
        </div>
      </q-card-section>
    </q-card>

    <div class="row">
      <div class="col-12">
        <GenericSubmitter
          :lastChangedField="lastChangedField"
          :currentModelForEditing="currentModelForEditing"
          @changesCanceled="changesCanceled"
          @runModelUpdate="runModelUpdate"
        ></GenericSubmitter>
      </div>
    </div>
  </div>
</template>
<script>
import PageBlockItem from "~/v-admin-app/src/components/pages/PageBlockItem.vue"
import usePages from "~/v-admin-app/src/compose/usePages.js"
import GenericSubmitter from "~/v-admin-app/src/components/editor-forms-parts/GenericSubmitter.vue"
export default {
  components: {
    PageBlockItem,
    GenericSubmitter,
  },
  computed: {
    currentModelForEditing() {
      return this.pagePartDetails.block_contents[this.currentBlockLocale]
        ? this.pagePartDetails.block_contents[this.currentBlockLocale]
        : {}
    },
  },
  methods: {
    changesCanceled() {
      this.cancelPendingChanges = true
    },
    runModelUpdate(currPendingChanges) {
      let blockDetailsToSave = {
        page_part_key: this.$route.params.pageTabName,
        locale: this.currentBlockLocale,
        blocks: {
          // main_content: {
          //   content: "...",
          // },
        },
      }
      this.pagePartDetails.editor_setup.editorBlocks.forEach(
        (editorBlockContainer) => {
          // editorBlocks are an array of arrays
          editorBlockContainer.forEach((editorBlockElement) => {
            // over here I go through each possible block item to
            // set to its previous value
            let blockLabel = editorBlockElement.label
            let originalBlockContent =
              this.pagePartDetails.block_contents[this.currentBlockLocale].blocks[
                blockLabel
              ]
            blockDetailsToSave.blocks[blockLabel] = originalBlockContent || {
              content: "",
            }
          })
        }
      )
      let pageSlug = this.$route.params.pageName
      // and now set with new values
      Object.keys(currPendingChanges).forEach((changeKey) => {
        blockDetailsToSave.blocks[changeKey] = {
          content: currPendingChanges[changeKey],
        }
      })
      this.updatePageFragment(pageSlug, blockDetailsToSave)
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
    },
  },
  props: {
    pagePartDetails: {},
    // editorBlockItem: {},
    editorBlocks: {},
    currentBlockLocale: {},
  },
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
