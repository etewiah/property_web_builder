<template>
  <div>
    <div>
      <div class="image-field-ctr q-px-none">
        <div>
          <q-img class="" :src="localFieldValue" />
        </div>
        <q-uploader
          :headers="imageUploadHeaders"
          @uploaded="imagesUploaded"
          @removed="filesRemoved"
          @added="filesAdded"
          ref="qUploaderRef"
          :url="imageUploadUrl"
          field-name="file"
          label="Custom header"
          multiple
          batch
        >
          <template v-slot:list="scope">
            <!-- <div v-if="filesToUploadCount < 1">
              <q-img class="" :src="localFieldValue" />
            </div>
            <div v-else>
              <q-img class="" :ratio="16 / 9" :src="scope.files[0].__img.src" />
            </div> -->
          </template>
          <template v-slot:header="scope">
            <div
              v-if="filesToUploadCount < 1"
              class="row no-wrap items-center q-pa-sm q-gutter-xs"
            >
              <!-- <q-btn
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
              </q-btn> -->
              <q-spinner v-if="scope.isUploading" class="q-uploader__spinner" />
              <div class="col">
                <div class="q-uploader__title">
                  <q-btn
                    v-if="scope.canAddFiles"
                    type="a"
                    icon="mode_edit"
                    @click="scope.pickFiles"
                    flat
                  >
                    Change Photo <q-uploader-add-trigger />
                    <q-tooltip>Pick Files</q-tooltip>
                  </q-btn>
                </div>
              </div>

              <!-- <q-btn
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
              </q-btn> -->
            </div>
          </template>
        </q-uploader>
      </div>
    </div>
  </div>
</template>
<script>
export default {
  props: {
    fieldDetails: {},
    currentFieldValue: {},
    cancelPendingChanges: {},
    autofocus: {},
  },
  data() {
    return {
      localFieldValue: "",
      originalValue: "",
      filesToUploadCount: 0,
      filesUploadedCount: 0,
    }
  },
  watch: {
    cancelPendingChanges(newValue, oldValue) {
      if (oldValue === false) {
        // when cancelPendingChanges on parent changes from
        // false to true
        // reset model to its original value
        this.localFieldValue = this.originalValue
      }
    },
    currentFieldValue: {
      handler(newValue, oldVal) {
        // This is effectively an initializer
        // that will not change as a result of typing
        // Will retrigger though when an update is pushed
        // to the server
        if (newValue) {
          if (this.fieldDetails.fieldType === "localesHash") {
            newValue = newValue[this.fieldDetails.activeLocale]
          }
          if (this.fieldDetails.inputType === "moneyField") {
            newValue = newValue / 100
          }
        }
        this.localFieldValue = newValue
        this.originalValue = newValue
      },
      // deep: true,
      immediate: true,
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
      let pageSlug = this.$route.params.pageName
      let pagePartKey = this.$route.params.pageTabName
      let imageUploadUrl = `/api/v1/pages/photos/${pageSlug}/${pagePartKey}/${this.fieldDetails.fieldName}`
      return imageUploadUrl
    },
  },
  methods: {
    imagesUploaded(uploadDetails) {
      this.filesUploadedCount += uploadDetails.files.length
      if (this.filesToUploadCount === this.filesUploadedCount) {
        let newImageUrl = JSON.parse(uploadDetails.xhr.response).image_url
        this.localFieldValue = newImageUrl
        this.$emit("updatePendingChanges", {
          fieldDetails: this.fieldDetails,
          newValue: newImageUrl,
        })
      }
    },
    filesRemoved(files) {
      this.filesToUploadCount -= files.length
    },
    filesAdded(files) {
      this.filesToUploadCount += files.length
      // below triggers file upload right away instead
      // of waiting for upload btn to be clicked
      this.$refs.qUploaderRef.upload()
    },
  },
}
</script>
<style>
.image-field-ctr .q-uploader {
  width: 200px;
}
.image-field-ctr .q-uploader__list {
  display: none;
}
</style>
