<template>
  <div class="">
    <q-responsive class="col" :ratio="16 / 9" style="max-width: 100%">
      <q-carousel
        swipeable
        thumbnails
        animated
        v-model="slideModel"
        :autoplay="autoplay"
        ref="carousel"
        infinite
        arrows
        control-type="regular"
        control-color="orange"
        control-text-color="grey-8"
        class="bg-purple text-white rounded-borders"
        v-model:fullscreen="fullscreen"
      >
        <q-carousel-slide
          v-for="image in carouselSlides"
          :name="image.src"
          :key="image.src"
          :img-src="image.src"
        >
          <q-scroll-area class="fit"> </q-scroll-area>
        </q-carousel-slide>
        <template v-slot:control>
          <q-carousel-control position="bottom-right" :offset="[18, 18]">
            <q-btn
              push
              round
              dense
              color="white"
              text-color="primary"
              :icon="fullscreen ? 'fullscreen_exit' : 'fullscreen'"
              @click="fullscreen = !fullscreen"
            />
          </q-carousel-control>
          <!-- <q-carousel-control
            position="top-right"
            :offset="[18, 18]"
            class="text-white rounded-borders"
            style="background: rgba(0, 0, 0, 0.3); padding: 4px 8px"
          >
            <q-toggle
              dense
              dark
              color="orange"
              v-model="autoplay"
              label="Auto Play"
            />
          </q-carousel-control> -->

          <!-- <q-carousel-control
            position="bottom-right"
            :offset="[18, 18]"
            class="q-gutter-xs"
          >
            <q-btn
              push
              round
              dense
              color="orange"
              text-color="black"
              icon="arrow_left"
              @click="$refs.carousel.previous()"
            />
            <q-btn
              push
              round
              dense
              color="orange"
              text-color="black"
              icon="arrow_right"
              @click="$refs.carousel.next()"
            />
          </q-carousel-control> -->
        </template>
      </q-carousel>
    </q-responsive>
  </div>
</template>
<script>
import { ref, toRef, watch } from "vue"
// import { sharedConfig } from "boot/shared-config"
// import { toRef, watch } from "vue"
export default {
  setup(props) {
    // let showThumbnailsRef = ref(props, "showThumbnails")
    // console.log(showThumbnailsRef.value)
    // // watch(
    // //   () => showThumbnailsRef,
    // //   (showThumbnails, prevshowThumbnails) => {
    // //     console.log("deep ", showThumbnails.value, prevshowThumbnails.value)
    // //   },
    // //   { deep: true }
    // // )
    // watch(showThumbnailsRef, (newValue, oldValue) => {
    //   console.log(
    //     "The new showThumbnailsRef value is: " + showThumbnailsRef.value
    //   )
    // })
    return {
      // showThumbnailsRef,
      slideModel: ref(1),
      autoplay: ref(false),
      fullscreen: ref(false),
    }
  },
  data() {
    return {}
  },
  props: {
    showThumbnails: {
      type: Boolean,
      default: false,
    },
    currentListing: {
      type: Object,
      default: () => {},
    },
  },
  watch: {
    carouselSlides: {
      // deep: true,
      handler: function (newVal) {
        if (newVal[0]) {
          this.slideModel = newVal[0].src
        }
      },
    },
  },
  computed: {
    carouselSlides() {
      var carouselSlides = []
      var picsColl = this.currentListing.propPhotos || []
      picsColl.forEach(function (picObject, index) {
        let imageUrl = picObject.image
        if (imageUrl[0] === "/") {
          // imageUrl = `${dataApiBase}${picObject.image_details.url}`
        }
        carouselSlides.push({
          thumb: imageUrl,
          src: imageUrl,
          alt_text: "",
        })
      })
      return carouselSlides
    },
  },
}
</script>
