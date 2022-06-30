<template>
  <div>
    <div v-for="pageContent in pageContents" :key="pageContent.id">
      <div v-html="pageContent"></div>
    </div>
  </div>
</template>
<script>
import { defineComponent, ref } from "vue"
import { useQuery } from "@urql/vue"
import { useRouter, useRoute } from "vue-router"
export default defineComponent({
  name: "PageContainer",
  components: {},
  computed: {
    pageContents() {
      let pageContents = []
      if (this.data && this.data.findPage.pageContents) {
        // pageContents[0].content.raw_en
        this.data.findPage.pageContents.forEach((pageContent) => {
          if (pageContent.content) {
            pageContents.push(pageContent.content.raw_en)
          }
        })
      }
      return pageContents
    },
    // pageBlocks() {
    //   let pageBlocks = []
    //   if (this.data && this.data.findPage.pageParts) {
    //     this.data.findPage.pageParts.forEach((pagePart) => {
    //       if (
    //         pagePart.blockContents["en"] &&
    //         pagePart.blockContents["en"].page_part_key === "content_html"
    //       ) {
    //         let mainContentHtml =
    //           pagePart.blockContents["en"].blocks.main_content.content
    //         pageBlocks.push(mainContentHtml)
    //       }
    //     })
    //   }
    //   return pageBlocks
    // },
  },
  mounted: function () {},
  data() {
    return {}
  },
  setup() {
    // const router = useRouter()
    const route = useRoute()
    let pageSlug = "home"
    if (route.name === "rPublicPage") {
      pageSlug = route.params.pageSlug
    }
    const result = useQuery({
      query: `
        query {
          findPage(slug: "${pageSlug}") {
            rawHtml,
            pageContents {
              content
            },
            pageParts {
              blockContents
              pageSlug
            }
          }
        }
      `,
    })

    return {
      fetching: result.fetching,
      data: result.data,
      error: result.error,
    }
  },
})
</script>
