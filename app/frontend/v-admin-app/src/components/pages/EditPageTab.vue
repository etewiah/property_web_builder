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
          <div>
            <EditPageBlocks
              :pagePartDetails="pagePartDetails"
              :editorBlocks="editorBlocks"
              :editorLocale="editorLocale"
            >
            </EditPageBlocks>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
// import EditPageBlock from "~/v-admin-app/src/components/pages/EditPageBlock.vue"
import EditPageBlocks from "~/v-admin-app/src/components/pages/EditPageBlocks.vue"
import loFind from "lodash/find"
export default {
  components: {
    // EditPageBlock,
    EditPageBlocks,
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
  methods: {},
  props: {
    pageContents: {},
    pagePartDetails: {},
  },
  data() {
    return {}
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
