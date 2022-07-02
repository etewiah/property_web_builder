<template>
  <div>
    {{ convertedPrice }}
    <span v-if="showOriginalPrice"> ({{ originalPrice }}) </span>
  </div>
</template>
<script>
export default {
  // inject: ["currentUserProvider"],
  components: {},
  data() {
    return {
      // localFieldValue: "",
    }
  },
  props: {
    interestedInOriginalPrice: {
      type: Boolean,
      default: true,
    },
    priceInCents: {
      type: Number,
      default: null,
    },
    originalCurrency: {
      type: String,
      default: "USD",
    },
  },
  computed: {
    currencyToUse() {
      // When I implement currency conversions I will set below to the current
      // user's preference
      return this.originalCurrency // this.currentUserProvider.getCurrencyToUse()
    },
    showOriginalPrice() {
      return (
        this.interestedInOriginalPrice &&
        this.originalCurrency !== this.currencyToUse
      )
    },
    originalPrice() {
      let originalPrice = this.priceInCents / 100
      return new Intl.NumberFormat("en", {
        style: "currency",
        currency: this.originalCurrency,
        maximumFractionDigits: 0,
      }).format(originalPrice)
    },
    convertedPrice() {
      let convertedPrice = this.priceInCents / 100
      if (this.originalCurrency !== this.currencyToUse) {
        let currencyRates = [] // this.currentUserProvider.state.currencyRates
        if (Object.keys(currencyRates).length < 1) {
          return convertedPrice
        }
        let priceInUsd = convertedPrice
        if (this.originalCurrency !== "USD") {
          let toUsdRateName = `${this.originalCurrency}`
          let toUsdRate = currencyRates.rates[toUsdRateName] // currencyRates[toUsdRateName]
          priceInUsd = convertedPrice / parseFloat(toUsdRate)
        }
        if (this.currencyToUse === "USD") {
          convertedPrice = priceInUsd
        } else {
          let targetRateName = `${this.currencyToUse}`
          let targetRate = currencyRates.rates[targetRateName]
          convertedPrice = priceInUsd * parseFloat(targetRate)
        }
      }
      return new Intl.NumberFormat("en", {
        style: "currency",
        currency: this.currencyToUse,
        maximumFractionDigits: 0,
      }).format(convertedPrice)
      // return convertedPrice
    },
  },
  methods: {},
}
</script>
