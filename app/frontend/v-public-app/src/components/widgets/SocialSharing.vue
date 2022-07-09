<template>
  <div>
    <q-page-sticky expand position="bottom"> </q-page-sticky>
    <div class="q-pa-lg flex justify-center">
      <div class="q-pa-sm">
        <a
          class="fb-share-link hover:scale-125 transform border-solid border border-white rounded-full w-12 h-12 flex justify-center items-center"
          target="_blank"
          rel="nofollow noreferrer"
          :href="`//www.facebook.com/sharer/sharer.php?u=${urlToShare}`"
        >
          <q-icon
            :name="mdiFacebook"
            class="text-white"
            style="font-size: 2rem; padding: 8px"
          />
        </a>
      </div>
      <div class="q-pa-sm">
        <a
          class="tw-share-link hover:scale-125 transform border-none rounded-full w-12 h-12 flex justify-center items-center"
          target="_blank"
          rel="nofollow noreferrer"
          :href="`https://twitter.com/intent/tweet?text=${socialSharingTitle} ${urlToShare}`"
        >
          <q-icon
            :name="mdiTwitter"
            class="text-white"
            style="font-size: 2rem; padding: 8px"
          />
        </a>
      </div>
      <div class="q-pa-sm">
        <a
          class="whatsapp-share-link hover:scale-125 transform border-none rounded-full w-12 h-12 flex justify-center items-center"
          target="_blank"
          rel="nofollow noreferrer"
          :href="`https://wa.me/?text=${socialSharingTitle} ${urlToShare}`"
        >
          <q-icon
            :name="mdiWhatsapp"
            class="text-white"
            style="font-size: 2rem; padding: 8px"
          />
        </a>
      </div>
      <div class="q-pa-sm">
        <a
          class="linked-in-share-link hover:scale-125 transform border-none rounded-full w-12 h-12 flex justify-center items-center"
          target="_blank"
          rel="nofollow noreferrer"
          :href="`//www.linkedin.com/shareArticle?mini=true&url=${urlToShare}&title=${socialSharingTitle}`"
        >
          <q-icon
            :name="mdiLinkedin"
            class="text-white"
            style="font-size: 2rem; padding: 8px"
          />
        </a>
      </div>
      <div class="q-pa-sm">
        <a
          class="email-share-link hover:scale-125 transform border-none rounded-full w-12 h-12 flex justify-center items-center"
          target="_blank"
          rel="nofollow noreferrer"
          :href="`mailto:?subject=${socialSharingTitle}&body=${urlToShare}`"
        >
          <q-icon
            :name="mdiEmailBox"
            class="text-white"
            style="font-size: 2rem; padding: 8px"
          />
        </a>
      </div>
    </div>
  </div>
</template>
<script>
// import { ref, toRef, watch } from "vue"
import {
  mdiTwitter,
  mdiLinkedin,
  mdiEmailBox,
  mdiFacebook,
  mdiWhatsapp,
} from "@quasar/extras/mdi-v5"
export default {
  created() {
    this.mdiTwitter = mdiTwitter
    this.mdiLinkedin = mdiLinkedin
    this.mdiEmailBox = mdiEmailBox
    this.mdiFacebook = mdiFacebook
    this.mdiWhatsapp = mdiWhatsapp
  },
  data() {
    return {}
  },
  props: {
    urlProp: {
      type: String,
    },
    sharingTitle: {
      type: String,
    },
  },
  watch: {},
  computed: {
    socialSharingTitle() {
      return this.sharingTitle || "Have a look at this:"
    },
    urlToShare() {
      let origin = ""
      if (typeof window !== "undefined") {
        origin = window.location.origin
      }
      // TODO - figure out way of ensuring origin is available - even when server rendered
      debugger
      return this.urlProp || `${origin}${this.$route.href}`
    },
  },
}
</script>
<style scoped>
.whatsapp-share-link {
  background-color: #00bf8f !important;
}
.fb-share-link {
  background-color: #3b5998;
}
.linked-in-share-link {
  background-color: #007bb5;
}
.tw-share-link {
  background-color: #55acee;
}
.email-share-link {
  background-color: #00bf8f;
}
</style>
