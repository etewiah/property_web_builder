<template>
  <div>
    <div class="q-pa-md">
      <div class="raw-display-el">
        Page tab for {{ pagePartDetails.page_part_key }}...
      </div>
      <div
        v-if="pagePartDetails.page_part_key === 'title'"
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
          <div>
            <div
              class="raw-display-el"
              v-html="tabPageContents[`raw_${editorLocale}`]"
            ></div>
          </div>
          <q-card
            v-for="editorBlock in editorBlocks"
            :key="editorBlock.nada"
            class="translation-item-card"
          >
            <q-card-section
              v-for="editorBlockItem in editorBlock"
              :key="editorBlockItem.label"
            >
              <div>{{ editorBlockItem.label }}</div>

              <EditPageBlock
                :pagePartDetails="pagePartDetails"
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
import loFind from "lodash/find"
// import useTranslations from "~/v-admin-app/src/compose/useTranslations.js"
// import TranslationInput from "~/v-admin-app/src/components/editor-forms-parts/TranslationInput.vue"
export default {
  components: {
    EditPageBlock,
  },
  computed: {
    tabPageContents() {
      let tabPageContents = {}
      let pageTabName = this.$route.params.pageTabName
      tabPageContents = loFind(this.pageContents, function (pc) {
        return pc["content_page_part_key"] === pageTabName
      })
      return tabPageContents.content
    },
    editorBlocks() {
      return this.pagePartDetails.editor_setup.editorBlocks
    },
  },
  methods: {},
  props: {
    pageContents: {},
    pagePartDetails: {},
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
