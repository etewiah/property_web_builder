<template>
  <div class="q-ma-md">
    <div v-for="pageContent in pageContents" :key="pageContent.id">
      <div v-html="pageContent"></div>
    </div>
    <div class="row q-col-gutter-md">
      <div
        class="col-sm-6 col-md-4"
        v-for="property in properties"
        :key="property.id"
      >
        <ListingsSummaryCard :currentListing="property"></ListingsSummaryCard>
      </div>
    </div>
  </div>
</template>
<script>
import ListingsSummaryCard from "~/v-public-app/src/components/cards/ListingsSummaryCard.vue"
import { defineComponent, ref } from "vue"
import { useQuery } from "@urql/vue"
import { useRouter, useRoute } from "vue-router"
export default defineComponent({
  name: "PageContainer",
  components: {
    ListingsSummaryCard,
  },
  computed: {
    properties() {
      let properties = this.data ? this.data.getProperties : []
      return properties
    },
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
  },
  mounted: function () {},
  data() {
    return {}
  },
  setup() {
    // const router = useRouter()
    const route = useRoute()
    let pageSlug = "rent"
    if (route.name === "rForSaleSearch") {
      pageSlug = "buy"
    }
    const result = useQuery({
      query: `
        query {
          getProperties {
            propPhotos {
              createdAt
              image
            },
            streetAddress,
            title,
            description
          }
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
