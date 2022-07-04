<template>
  <div>
    <div v-for="pageContent in pageContents" :key="pageContent.id">
      <div v-html="pageContent"></div>
    </div>
  </div>
</template>
<script>
import { defineComponent, ref, computed } from "vue"
import { useQuery } from "@urql/vue"
import { useRouter, useRoute } from "vue-router"
export default defineComponent({
  name: "PageContainer",
  components: {},
  computed: {
    pageContents() {
      let pageContents = []
      if (this.gqlError) {
        this.$q.notify({
          color: "negative",
          position: "top",
          message: this.gqlError.message,
          icon: "report_problem",
        })
      } else {
        if (this.gqlData && this.gqlData.findPage.pageContents) {
          let contentKey = `raw_${this.publicLocale}`
          // pageContents[0].content.raw_en
          this.gqlData.findPage.pageContents.forEach((pageContent) => {
            if (pageContent.content) {
              pageContents.push(pageContent.content[contentKey])
            }
          })
        }
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
    const publicLocale = ref(route.params.publicLocale)
    const result = useQuery({
      pause: computed(() => !publicLocale.value),
      variables: {
        publicLocale,
      },
      query: `
        query ($publicLocale: String! ) {
          findPage(slug: "${pageSlug}", locale: $publicLocale) {
            rawHtml,
            pageTitle,
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
      publicLocale,
      gqlFetching: result.fetching,
      gqlData: result.data,
      gqlError: result.error,
    }
  },
})
</script>
