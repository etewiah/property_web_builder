<template>
  <div
    class="spp-listing-main-edit bg-gray-200 leading-normal tracking-normal"
    style="font-family: 'Source Sans Pro', sans-serif"
  >
    <div class="selectable-images-container q-pa-md">
      <div class="sic-list row q-col-gutter-md" bordered padding>
        <div
          class="col-xs-12 col-sm-12 col-md-4"
          v-for="(imageItem, index) in imageOptions"
          :key="index"
        >
          <q-card class="img-picker-item-card">
            <q-card-section class="q-pa-none">
              <q-item-section class="column items-center" avatar>
                <div>
                  <q-btn
                    type="a"
                    icon="delete_forever"
                    @click="showDeleteImageConfirmation(imageItem)"
                    round
                    dense
                    flat
                  >
                    <q-tooltip>Delete this image forever</q-tooltip>
                  </q-btn>
                </div>
              </q-item-section>
              <q-item-section @click="imageClicked(imageItem.value)" horizontal>
                <q-img class="" :ratio="16 / 9" :src="imageItem.label" />
              </q-item-section>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-xs-12 col-sm-12 col-md-4">
          <div class="q-px-none">
            <q-uploader
              :headers="imageUploadHeaders"
              @uploaded="imagesUploaded"
              @removed="filesRemoved"
              @added="filesAdded"
              ref="qUploaderRef"
              :url="imageUploadUrl"
              field-name="file"
              label="Custom header"
              class="full-width"
              style="min-height: 350px"
              multiple
              batch
            >
              <template v-slot:header="scope">
                <div class="row no-wrap items-center q-pa-sm q-gutter-xs">
                  <q-btn
                    v-if="scope.queuedFiles.length > 0"
                    icon="clear_all"
                    @click="scope.removeQueuedFiles"
                    round
                    dense
                    flat
                  >
                    <q-tooltip>Clear All</q-tooltip>
                  </q-btn>
                  <q-btn
                    v-if="scope.uploadedFiles.length > 0"
                    icon="done_all"
                    @click="scope.removeUploadedFiles"
                    round
                    dense
                    flat
                  >
                    <q-tooltip>Remove Uploaded Files</q-tooltip>
                  </q-btn>
                  <q-spinner
                    v-if="scope.isUploading"
                    class="q-uploader__spinner"
                  />
                  <div class="col">
                    <div class="q-uploader__title">Upload Images</div>
                    <div class="q-uploader__subtitle">
                      {{ scope.uploadSizeLabel }} /
                      {{ scope.uploadProgressLabel }}
                    </div>
                  </div>
                  <q-btn
                    v-if="scope.canAddFiles"
                    type="a"
                    icon="add_box"
                    @click="scope.pickFiles"
                    round
                    dense
                    flat
                  >
                    <q-uploader-add-trigger />
                    <q-tooltip>Pick Files</q-tooltip>
                  </q-btn>
                  <q-btn
                    v-if="scope.canUpload"
                    icon="cloud_upload"
                    @click="scope.upload"
                    round
                    dense
                    flat
                  >
                    <q-tooltip>Upload Files</q-tooltip>
                  </q-btn>

                  <q-btn
                    v-if="scope.isUploading"
                    icon="clear"
                    @click="scope.abort"
                    round
                    dense
                    flat
                  >
                    <q-tooltip>Abort Upload</q-tooltip>
                  </q-btn>
                </div>
              </template>
            </q-uploader>
          </div>
        </div>
      </div>
    </div>
    <q-dialog v-model="showConfirmationModal">
      <q-card>
        <q-card-section>
          <div class="text-h6">Are you sure you want to delete this image?</div>
        </q-card-section>
        <q-card-section class="q-pt-none"> </q-card-section>
        <q-card-actions align="right">
          <q-btn
            flat
            label="Delete"
            color="danger"
            @click="startImageDelete"
            v-close-popup
          />
          <q-btn flat label="Cancel" color="primary" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>
<script>
import { defineComponent, ref } from "vue"
import useProperties from "~/v-admin-app/src/compose/useProperties.js"
export default defineComponent({
  // inject: ["listingsEditProvider", "pboardItemEditProvider", "hhpProvider"],
  components: {},
  mounted() {},
  setup() {
    // const $q = useQuasar()
    const { deletePropertyPhoto } = useProperties()
    return { deletePropertyPhoto }
  },
  data() {
    return {
      selectedImageProxy: "",
      showConfirmationModal: false,
      imageToDelete: null,
      filesToUploadCount: 0,
      filesUploadedCount: 0,
    }
  },
  methods: {
    imageClicked(newValue) {},
    startImageDelete() {
      if (this.imageToDelete) {
        this.deletePropertyPhoto(this.imageToDelete).then((response) => {
          // TODO - find a better way to refresh than this:
          location.reload()
        })
      }
    },
    showDeleteImageConfirmation(imageToDelete) {
      this.showConfirmationModal = true
      this.imageToDelete = imageToDelete
    },
    imagesUploaded(uploadDetails) {
      this.filesUploadedCount += uploadDetails.files.length
      if ((this.filesToUploadCount === this.filesUploadedCount)) {
        location.reload()
      }
    },
    filesRemoved(files) {
      this.filesToUploadCount -= files.length
    },
    filesAdded(files) {
      this.filesToUploadCount += files.length
    },
  },
  computed: {
    imageUploadHeaders() {
      let authHeaderVal = {}
      let csrfToken = document.head.querySelector("[name='csrf-token']").content
      authHeaderVal = {
        name: "X-CSRF-Token",
        value: csrfToken,
      }
      return [authHeaderVal]
    },
    imageUploadUrl() {
      let imageUploadUrl = `/api/v1/properties/${this.currentProperty.id}/photo`
      return imageUploadUrl
    },
    imageOptions() {
      let options = []
      let allPhotosForSpp = this.currentProperty.attributes.photos || []
      let propId = this.currentProperty.id
      allPhotosForSpp.forEach(function (sppPhoto) {
        let imageUrl = sppPhoto.image.url
        // if (imageUrl[0] === "/") {
        //   imageUrl = `${sppPhoto.image.url}`
        // }
        options.push({
          label: imageUrl,
          value: imageUrl,
          image_url: imageUrl,
          id: sppPhoto.id,
          prop_id: propId
        })
      })
      return options
    },
    sppViewData() {
      return {}
    },
  },
  props: {
    currentProperty: {
      type: Object,
      default: () => {},
    },
  },
})
</script>
