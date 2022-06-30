<template>
  <div>
    <div v-for="pageBlock in pageBlocks" :key="pageBlock.id">
      <div v-html="pageBlock"></div>
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
    pageBlocks() {
      let pageBlocks = []
      if (this.data && this.data.findPage.pageParts) {
        this.data.findPage.pageParts.forEach((pagePart) => {
          if (
            pagePart.blockContents["en"] &&
            pagePart.blockContents["en"].page_part_key === "content_html"
          ) {
            let mainContentHtml =
              pagePart.blockContents["en"].blocks.main_content.content
            pageBlocks.push(mainContentHtml)
          }
        })
      }
      return pageBlocks
    },
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
            pageParts {
              blockContents
              createdAt
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
