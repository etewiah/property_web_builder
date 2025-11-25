<template>
  <div>
    <div class="q-pa-md">
      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-6">
          <q-card class="q-mb-md">
            <q-card-section>
              <div class="text-h6 nav-group-label">Top Navigation</div>
            </q-card-section>
            <q-card-section>
              <q-list bordered separator>
                <q-item v-for="(navLink, index) in currentNavLinks.top_nav_links" :key="navLink.slug">
                  <q-item-section>
                    <q-item-label>{{ navLink.link_title }}</q-item-label>
                    <q-item-label caption>{{ navLink.link_path }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <div class="row items-center">
                      <q-btn flat round dense icon="arrow_upward" @click="moveLink(index, -1, 'top_nav_links')" :disable="index === 0" />
                      <q-btn flat round dense icon="arrow_downward" @click="moveLink(index, 1, 'top_nav_links')" :disable="index === currentNavLinks.top_nav_links.length - 1" />
                      <q-btn flat round dense icon="edit" @click="editLink(navLink, 'top_nav_links')" />
                      <ToggleField
                        :cancelPendingChanges="cancelPendingChanges"
                        :fieldDetails="navLink"
                        v-on:updatePendingChanges="updatePendingChanges"
                      ></ToggleField>
                    </div>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-6">
          <q-card class="q-mb-md">
            <q-card-section>
              <div class="text-h6 nav-group-label">Footer Navigation</div>
            </q-card-section>
            <q-card-section>
              <q-list bordered separator>
                <q-item v-for="(navLink, index) in currentNavLinks.footer_links" :key="navLink.slug">
                  <q-item-section>
                    <q-item-label>{{ navLink.link_title }}</q-item-label>
                    <q-item-label caption>{{ navLink.link_path }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <div class="row items-center">
                      <q-btn flat round dense icon="arrow_upward" @click="moveLink(index, -1, 'footer_links')" :disable="index === 0" />
                      <q-btn flat round dense icon="arrow_downward" @click="moveLink(index, 1, 'footer_links')" :disable="index === currentNavLinks.footer_links.length - 1" />
                      <q-btn flat round dense icon="edit" @click="editLink(navLink, 'footer_links')" />
                      <ToggleField
                        :cancelPendingChanges="cancelPendingChanges"
                        :fieldDetails="navLink"
                        v-on:updatePendingChanges="updatePendingChanges"
                      ></ToggleField>
                    </div>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card-section>
          </q-card>
        </div>
      </div>
      <div class="row">
        <div class="col-12">
          <LinksSubmitter
            :cancelPendingChanges="cancelPendingChanges"
            :lastChangedField="lastChangedField"
            :currentModelForEditing="currentNavLinks"
            @changesCanceled="changesCanceled"
            @runModelUpdate="runModelUpdate"
          ></LinksSubmitter>
        </div>
      </div>

      <q-dialog v-model="showEditDialog">
        <q-card style="min-width: 350px">
          <q-card-section>
            <div class="text-h6">Edit Link</div>
          </q-card-section>

          <q-card-section class="q-pt-none">
            <q-input dense v-model="editingLink.link_title" label="Title" autofocus />
            <q-input dense v-model="editingLink.link_path" label="Path/URL" />
          </q-card-section>

          <q-card-actions align="right" class="text-primary">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn flat label="Save" @click="saveLinkEdit" v-close-popup />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </div>
</template>
<script>
// import { defineComponent, ref } from "vue"
import ToggleField from "~/v-admin-app/src/components/editor-forms-parts/ToggleField.vue"
import LinksSubmitter from "~/v-admin-app/src/components/editor-forms-parts/LinksSubmitter.vue"
import useLinks from "~/v-admin-app/src/compose/useLinks.js"
export default {
  components: {
    LinksSubmitter,
    ToggleField,
  },
  methods: {
    moveLink(index, direction, groupName) {
      const links = this.currentNavLinks[groupName]
      const newIndex = index + direction
      if (newIndex >= 0 && newIndex < links.length) {
        const item = links.splice(index, 1)[0]
        links.splice(newIndex, 0, item)
        // Update sort_order for all items in the group
        links.forEach((link, i) => {
          link.sort_order = i
        })
        // Trigger update
        this.updatePendingChanges({
          fieldDetails: { slug: 'reorder' }, // Dummy field details to trigger update
          newValue: true,
          navGroup: groupName
        })
      }
    },
    editLink(link, groupName) {
      this.editingLink = { ...link }
      this.editingGroup = groupName
      this.showEditDialog = true
    },
    saveLinkEdit() {
      const group = this.currentNavLinks[this.editingGroup]
      const index = group.findIndex(l => l.slug === this.editingLink.slug)
      if (index !== -1) {
        // Update the link in the list
        // group[index] = { ...this.editingLink } // This might lose reactivity
        Object.assign(group[index], this.editingLink)
        
        this.updatePendingChanges({
          fieldDetails: group[index],
          newValue: true, // Dummy value
          navGroup: this.editingGroup
        })
      }
    },
    runModelUpdate(currPendingChanges) {
      this.updateLinks(this.currentNavLinks)
        .then((response) => {
          // location.reload()
          // this.currPendingChanges = {}
          this.$q.notify({
            color: "green-4",
            textColor: "white",
            icon: "cloud_done",
            message: "Updated successfully",
          })
        })
        .catch((error) => {
          let errorMessage = error.message || "Sorry, unable to update"
          if (
            error.response.data.errors[0] &&
            error.response.data.errors[0].meta.exception
          ) {
            errorMessage = error.response.data.errors[0].meta.exception
          }
          this.$q.notify({
            color: "red-4",
            textColor: "white",
            icon: "error",
            message: errorMessage,
          })
        })
    },
    updatePendingChanges({ fieldDetails, newValue, navGroup }) {
      let newFieldDetails = {
        fieldName: fieldDetails.slug,
        navGroup: navGroup,
      }
      newFieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = newFieldDetails
      // this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  props: {},
  mounted: function () {
    this.getLinks()
      .then((response) => {
        this.currentNavLinks = response.data
      })
      .catch((error) => {})
  },
  setup(props) {
    const { getLinks, updateLinks } = useLinks()
    return {
      getLinks,
      updateLinks,
    }
  },
  data() {
    return {
      currentNavLinks: {
        top_nav_links: [],
        footer_links: []
      },
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
        // lastUpdateStamp: "",
      },
      showEditDialog: false,
      editingLink: {},
      editingGroup: ''
    }
  },
}
</script>
<style></style>
