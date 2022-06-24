<template>
  <div>
    <div class="q-pa-md">
      <div>Page tab for {{ pageTabDetails.page_part_key }}...</div>
      <div
        v-if="pageTabDetails.page_part_key === 'title'"
        class="row q-col-gutter-md"
      >
        Titl.....
      </div>
      <div v-else class="row q-col-gutter-md">
        <div
          class="col-12"
          v-for="editorLocale in ['en', 'es']"
          :key="editorLocale"
        >
          <div>{{ editorLocale }}</div>
          <q-card
            v-for="editorBlock in editorBlocks"
            :key="editorBlock.sortKey"
            class="translation-item-card"
          >
            <q-card-section
              v-for="editorBlockItem in editorBlock"
              :key="editorBlockItem.sortKey"
            >
              <div>{{ editorBlockItem.label }}</div>

              <EditPageBlock
                :pageTabDetails="pageTabDetails"
                :editorBlockItem="editorBlockItem"
                :editorLocale="editorLocale"
              >
              </EditPageBlock>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import EditPageBlock from "~/v-admin-app/src/components/pages/EditPageBlock.vue"
// import useTranslations from "~/v-admin-app/src/compose/useTranslations.js"
// import TranslationInput from "~/v-admin-app/src/components/editor-forms-parts/TranslationInput.vue"
export default {
  components: {
    EditPageBlock,
  },
  computed: {
    editorBlocks() {
      return this.pageTabDetails.editor_setup.editorBlocks
    },
  },
  methods: {},
  props: {
    pageTabDetails: {},
  },
  // mounted: function () {
  //   let batchName = this.$route.params.tBatchId
  //   // "extras"
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
    }
  },
}
</script>
<style></style>
