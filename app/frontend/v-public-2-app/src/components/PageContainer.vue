<template>
  <div>
    <div v-for="pageContent in pageContents" :key="pageContent.id">
      <div v-html="pageContent"></div>
    </div>
  </div>
</template>
<script>
import { defineComponent, ref, watch } from "vue"
import { useRoute } from "vue-router"
import axios from "axios"

export default defineComponent({
  name: "PageContainer",
  components: {},
  computed: {
    pageContents() {
      let pageContents = []
      if (this.error) {
        this.$q.notify({
          color: "negative",
          position: "top",
          message: this.error.message,
          icon: "report_problem",
        })
      } else {
        if (this.pageData && this.pageData.page_contents) {
          let contentKey = `raw_${this.publicLocale}`
          this.pageData.page_contents.forEach((pageContent) => {
            if (pageContent.content) {
              pageContents.push(pageContent.content[contentKey])
            }
          })
        }
      }
      return pageContents
    },
  },
  mounted: function () {},
  data() {
    return {}
  },
  setup() {
    const route = useRoute()
    let pageSlug = "home"
    if (route.name === "rPublicPage") {
      pageSlug = route.params.pageSlug
    }
    const publicLocale = ref(route.params.publicLocale)
    const loading = ref(false)
    const error = ref(null)
    const pageData = ref(null)

    const fetchPage = async (locale) => {
      if (!locale) return
      loading.value = true
      error.value = null
      try {
        const response = await axios.get(`/api_public/v1/pages/by_slug/${pageSlug}`, {
          params: { locale }
        })
        pageData.value = response.data
      } catch (err) {
        error.value = err
        console.error("Error fetching page:", err)
      } finally {
        loading.value = false
      }
    }

    watch(
      () => route.params.publicLocale,
      (newLocale) => {
        publicLocale.value = newLocale
        fetchPage(newLocale)
      },
      { immediate: true }
    )

    return {
      publicLocale,
      loading,
      pageData,
      error,
    }
  },
})
</script>
