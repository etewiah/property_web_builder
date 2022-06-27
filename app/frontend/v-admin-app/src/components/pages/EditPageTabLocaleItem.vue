<template>
  <div>
    <div class="text-h6 q-my-lg">Content in {{ supportedLocale.label }}:</div>
    <div v-if="showPreview">
      <div
        class="raw-display-el"
        v-html="tabPageContentItem.content[`raw_${supportedLocale.localeOnly}`]"
      ></div>
      <div class="q-mt-lg">
        <q-btn @click="setEditMode" color="primary" type="submit"> Edit </q-btn>
      </div>
    </div>
    <div v-else>
      <EditPageBlocks
        @cancelEditMode="cancelEditMode"
        :pagePartDetails="pagePartDetails"
        :editorBlocks="editorBlocks"
        :currentBlockLocale="supportedLocale.localeOnly"
      >
      </EditPageBlocks>
    </div>
  </div>
</template>
<script>
// import usePages from "~/v-admin-app/src/compose/usePages.js"
// import GenericSubmitter from "~/v-admin-app/src/components/editor-forms-parts/GenericSubmitter.vue"
// import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
import EditPageBlocks from "~/v-admin-app/src/components/pages/EditPageBlocks.vue"
import loFind from "lodash/find"
export default {
  inject: ["websiteProvider"],
  components: {
    // GenericSubmitter,
    EditPageBlocks,
    // TextField,
  },
  computed: {
    // tabPageContentItem() {
    //   let pageContentItem = {}
    //   let pageTabName = this.$route.params.pageTabName
    //   pageContentItem = loFind(this.pageContents, function (pc) {
    //     return pc["content_page_part_key"] === pageTabName
    //   })
    //   return pageContentItem ? pageContentItem : { visible_on_page: true }
    // },
    editorBlocks() {
      return this.pagePartDetails.editor_setup.editorBlocks
    },
  },
  // setup() {
  //   const { updatePage, updatePagePartVisibility } = usePages()
  //   return {
  //     updatePage,
  //     updatePagePartVisibility,
  //   }
  // },
  methods: {
    cancelEditMode() {
      this.showPreview = true
    },
    setEditMode() {
      this.showPreview = false
    },
  },
  props: {
    tabPageContentItem: {
      type: Object,
      default() {
        return {}
      },
    },
    supportedLocale: {
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
      showPreview: true,
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
.raw-display-el {
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
