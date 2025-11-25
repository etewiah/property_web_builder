<template>
  <div>
    <div class="q-pa-md">
      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-6">
          <q-card class="q-mb-md">
            <q-card-section>
              <div class="text-h6">Home Page Details</div>
            </q-card-section>
            <q-card-section>
              <q-input
                filled
                v-model="homePage.page_title"
                label="Page Title"
                class="q-mb-md"
              />
              <!-- Add more fields if needed, e.g. description -->
            </q-card-section>
            <q-card-actions align="right">
              <q-btn color="primary" label="Save Details" @click="savePageDetails" />
            </q-card-actions>
          </q-card>
        </div>

        <div class="col-12 col-md-6">
          <q-card class="q-mb-md">
            <q-card-section>
              <div class="text-h6">Carousel Images</div>
            </q-card-section>
            <q-card-section>
              <div class="row q-col-gutter-sm">
                <div v-for="content in carouselContents" :key="content.id" class="col-4 relative-position">
                  <q-img
                    :src="content.attributes.content_photos[0]?.image_url"
                    spinner-color="white"
                    style="height: 100px; max-width: 100%"
                    class="rounded-borders"
                  >
                    <div class="absolute-top-right text-subtitle2" style="padding: 0">
                       <q-btn round dense flat icon="delete" color="negative" @click="deleteImage(content.id)" />
                    </div>
                  </q-img>
                </div>
              </div>
            </q-card-section>
            <q-card-section>
              <q-file
                v-model="newImage"
                label="Upload Image"
                filled
                accept=".jpg, .jpeg, .png"
                @update:model-value="uploadImage"
              >
                <template v-slot:prepend>
                  <q-icon name="cloud_upload" />
                </template>
              </q-file>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { defineComponent, ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import usePage from "~/v-admin-app/src/compose/usePage.js"
import useWebContents from "~/v-admin-app/src/compose/useWebContents.js"

export default defineComponent({
  name: 'EditHomeSettings',
  setup() {
    const $q = useQuasar()
    const { getPage, updatePage } = usePage()
    const { getContents, createContentWithPhoto, deleteContent } = useWebContents()

    const homePage = ref({})
    const carouselContents = ref([])
    const newImage = ref(null)

    const loadHomePage = async () => {
      try {
        const response = await getPage('home')
        homePage.value = response.data
      } catch (error) {
        console.error('Error loading home page', error)
      }
    }

    const loadCarouselImages = async () => {
      try {
        const response = await getContents('landing_carousel')
        carouselContents.value = response.data.data // JSONAPI response structure
      } catch (error) {
        console.error('Error loading carousel images', error)
      }
    }

    const savePageDetails = async () => {
      try {
        await updatePage(homePage.value)
        $q.notify({
          color: 'positive',
          message: 'Home page details updated'
        })
      } catch (error) {
        $q.notify({
          color: 'negative',
          message: 'Failed to update details'
        })
      }
    }

    const uploadImage = async (file) => {
      if (!file) return
      try {
        await createContentWithPhoto('landing_carousel', file)
        $q.notify({
          color: 'positive',
          message: 'Image uploaded successfully'
        })
        newImage.value = null
        loadCarouselImages()
      } catch (error) {
        $q.notify({
          color: 'negative',
          message: 'Failed to upload image'
        })
      }
    }

    const deleteImage = async (id) => {
      try {
        await deleteContent(id)
        $q.notify({
          color: 'positive',
          message: 'Image deleted'
        })
        loadCarouselImages()
      } catch (error) {
        $q.notify({
          color: 'negative',
          message: 'Failed to delete image'
        })
      }
    }

    onMounted(() => {
      loadHomePage()
      loadCarouselImages()
    })

    return {
      homePage,
      carouselContents,
      newImage,
      savePageDetails,
      uploadImage,
      deleteImage
    }
  }
})
</script>
