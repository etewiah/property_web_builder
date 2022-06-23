<template>
  <q-layout view="lHh Lpr lFf">
    <q-header elevated>
      <q-toolbar>
        <q-btn
          flat
          dense
          round
          @click="toggleLeftDrawer"
          icon="menu"
          aria-label="Menu"
        />
        <q-toolbar-title>
          <strong>Property</strong><span style="color: black">Web</span
          ><strong class="navy--text text--darken-1">Builder</strong> &copy;
          2022 Admin
        </q-toolbar-title>
        <q-space />
        <div class="q-gutter-sm row items-center no-wrap">
          <q-btn
            round
            dense
            flat
            color="white"
            :icon="$q.fullscreen.isActive ? 'fullscreen_exit' : 'fullscreen'"
            @click="$q.fullscreen.toggle()"
            v-if="$q.screen.gt.sm"
          >
          </q-btn>
          <q-btn
            round
            dense
            flat
            color="white"
            icon="fab fa-github"
            type="a"
            href="/"
            target="_blank"
          >
          </q-btn>
          <q-btn
            round
            dense
            flat
            icon="fas fa-heart"
            style="color: #9d4182 !important"
            type="a"
            href="/"
            target="_blank"
          >
          </q-btn>
          <q-btn round dense flat color="white" icon="notifications">
            <q-badge color="red" text-color="white" floating> 5 </q-badge>
            <q-menu>
              <q-list style="min-width: 100px">
                <!-- <messages></messages> -->
                <q-card class="text-center no-shadow no-border">
                  <q-btn
                    label="View All"
                    style="max-width: 120px !important"
                    flat
                    dense
                    class="text-indigo-8"
                  ></q-btn>
                </q-card>
              </q-list>
            </q-menu>
          </q-btn>
          <q-btn round flat>
            <q-avatar size="26px">
              <img src="https://cdn.quasar.dev/img/boy-avatar.png" />
            </q-avatar>
          </q-btn>
        </div>
      </q-toolbar>
    </q-header>

    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      bordered
      class="bg-primary text-white"
    >
      <q-list>
        <q-item to="/" active-class="q-item-no-link-highlighting">
          <q-item-section avatar>
            <q-icon name="dashboard" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Home</q-item-label>
          </q-item-section>
        </q-item>
        <q-item
          :exact="true"
          :to="{ name: 'rAgencyEditGeneral' }"
          active-class="q-item-no-link-highlighting"
        >
          <q-item-section avatar>
            <q-icon name="dashboard" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Agency</q-item-label>
          </q-item-section>
        </q-item>
        <q-item
          :exact="false"
          :to="{
            name: 'rTranslationsEditBatch',
            params: { tBatchId: 'extras' },
          }"
          active-class="q-item-no-link-highlighting"
        >
          <q-item-section avatar>
            <q-icon name="dashboard" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Translations</q-item-label>
          </q-item-section>
        </q-item>
        <!-- <q-item to="/Dashboard2" active-class="q-item-no-link-highlighting">
          <q-item-section avatar>
            <q-icon name="dashboard" />
          </q-item-section>
          <q-item-section>
            <q-item-label>CRM Dashboard</q-item-label>
          </q-item-section>
        </q-item> -->
        <q-expansion-item
          :default-opened="true"
          aria-expanded="true"
          icon="pages"
          label="Properties"
        >
          <q-list class="q-pl-lg">
            <q-item
              :exact="true"
              :to="{ name: 'rPropertiesList' }"
              active-class="q-item-no-link-highlighting"
            >
              <q-item-section avatar>
                <q-icon name="list" />
              </q-item-section>
              <q-item-section>
                <q-item-label>List All</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </q-expansion-item>
        <q-expansion-item
          :default-opened="true"
          aria-expanded="true"
          icon="pages"
          label="Website"
        >
          <q-list class="q-pl-lg">
            <q-item
              :exact="false"
              :to="{ name: 'rWebsiteEditGeneral' }"
              active-class="q-item-no-link-highlighting"
            >
              <q-item-section avatar>
                <q-icon name="settings" />
              </q-item-section>
              <q-item-section>
                <q-item-label>Settings</q-item-label>
              </q-item-section>
            </q-item>
            <q-item
              :exact="false"
              :to="{ name: 'rWebsiteEditFooter' }"
              active-class="q-item-no-link-highlighting"
            >
              <q-item-section avatar>
                <q-icon name="lock" />
              </q-item-section>
              <q-item-section>
                <q-item-label>Footer</q-item-label>
              </q-item-section>
            </q-item>
            <!-- <q-item-label header class="text-weight-bolder text-white"
              >Generic</q-item-label
            >
            <q-item to="/" active-class="q-item-no-link-highlighting">
              <q-item-section avatar>
                <q-icon name="person" />
              </q-item-section>
              <q-item-section>
                <q-item-label>User Profile</q-item-label>
              </q-item-section>
            </q-item> -->
          </q-list>
        </q-expansion-item>
        <q-expansion-item
          :default-opened="true"
          aria-expanded="true"
          icon="pages"
          label="Pages"
        >
          <q-list class="q-pl-lg">
            <q-item
              :exact="true"
              :to="{ name: 'rPropertiesList' }"
              active-class="q-item-no-link-highlighting"
            >
              <q-item-section>
                <q-item-label>Home</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </q-expansion-item>
      </q-list>
    </q-drawer>

    <q-page-container class="bg-grey-2">
      <router-view />
    </q-page-container>
  </q-layout>
</template>
<script>
// import Messages from "./Messages";
import { defineComponent, ref } from "vue"
export default defineComponent({
  name: "MainLayout",
  components: {
    // Messages
  },
  setup() {
    const leftDrawerOpen = ref(false)
    return {
      leftDrawerOpen,
      toggleLeftDrawer() {
        leftDrawerOpen.value = !leftDrawerOpen.value
      },
    }
  },
})
</script>
