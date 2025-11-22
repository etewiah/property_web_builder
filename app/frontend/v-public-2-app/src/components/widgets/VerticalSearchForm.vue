<template>
  <div class="vert-search">
    <div class="q-mr-md">
      <span name="search-box-fade">
        <div>
          <div class="row">
            <!-- <div xs12>
              <div class="text-xs-left py-2 headline">
                <span class>Search</span>
              </div>
            </div> -->
            <div
              v-for="fieldDetails in orderedSearchFields"
              :key="fieldDetails.fieldName"
              class="col-sm-12 q-py-md"
            >
              <SelectField
                @selectChanged="triggerSearchUpdate"
                :fieldDetails="fieldDetails"
                :currentFieldValue="routeParams[fieldDetails.queryStringName]"
                :currentMinPriceValue="currentMinPriceValue"
              ></SelectField>
            </div>
          </div>
        </div>
      </span>
    </div>
  </div>
</template>
<script>
import SelectField from "~/v-public-app/src/components/fields/SelectField.vue"
import useSearchFields from "~/v-public-2-app/src/compose/useSearchFields.js"
import usePropertyTypes from "~/v-public-2-app/src/compose/usePropertyTypes.js"
import { useRoute } from "vue-router"
import { watch } from "vue"

export default {
  components: {
    SelectField,
  },
  setup() {
    const { getSearchFields } = useSearchFields()
    const { propertyTypes } = usePropertyTypes()
    const route = useRoute()
    let saleOrRental = "rental"
    if (route.name === "rForSaleSearch") {
      saleOrRental = "sale"
    }
    
    const searchFields = getSearchFields(saleOrRental)
    
    // Update property type options when they're loaded
    watch(propertyTypes, (newTypes) => {
      const propertyTypeField = searchFields.find(f => f.fieldName === "propertyType")
      if (propertyTypeField && newTypes.length > 0) {
        propertyTypeField.optionsValues = newTypes.map(t => t.value)
        // Store labels for display
        propertyTypeField.optionsLabels = newTypes
      }
    })
    
    return {
      searchFields,
    }
  },

  props: {
    currentSearchFieldsParams: {
      type: Object,
      default() {
        return {}
      },
    },
    routeParams: {
      type: Object,
      default() {
        return {}
      },
    },
    isLoading: {
      type: Boolean,
    },
    isMobileModal: {
      type: Boolean,
    },
  },
  methods: {
    triggerSearchUpdate(fieldDetails) {
      if (fieldDetails.fieldName === "minPrice") {
        this.newCurrentMinPriceValue = fieldDetails.newValue
      }
      // up the chain
      this.$emit("triggerSearchUpdate", fieldDetails)
    },
  },
  computed: {
    currentMinPriceValue() {
      return (
        this.newCurrentMinPriceValue ||
        this.currentSearchFieldsParams["price_min"]
      )
    },
    orderedSearchFields() {
      let searchFields = this.searchFields || []
      let sortedFields = searchFields.sort(
        (a, b) => a.sort_order - b.sort_order
      )
      return sortedFields
    },
  },
  data: () => ({
    newCurrentMinPriceValue: null,
  }),
  mounted: function () {},
}
</script>
<style scoped></style>
