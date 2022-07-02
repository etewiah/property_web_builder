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
                :fieldOptions="searchSelectOptions"
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
import useSearchFields from "~/v-public-app/src/compose/useSearchFields.js"
// import SearchField from "@jsroot/shared/components-form-fields/SearchFieldResolver"
export default {
  components: {
    SelectField,
  },
  setup() {
    const { getSearchFields } = useSearchFields()
    return {
      searchFields: getSearchFields(),
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
    searchSelectOptions: {
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
