// https://vuedose.tips/create-a-i18n-plugin-with-composition-api-in-vuejs-3
// const i18nSymbol = Symbol();
// export function provideI18n(i18nConfig) {
//   const i18n = createI18n(i18nConfig);
//   provide(i18nSymbol, i18n);
// }
// export function useI18n() {
//   const i18n = inject(i18nSymbol);
//   if (!i18n) throw new Error("No i18n provided!!!");

//   return i18n;
// }

import { ref, provide, inject, reactive, computed, readonly } from "vue";

const state = reactive({
  locale: "es",
  localeMessages: {
    en: {},
    es: {},
  }
})

// const createI18n = config => ({
//   locale: ref(config.locale),
//   localeMessages: ref(state.localeMessages),
//   $t(key) {
//     return this.localeMessages.value[this.locale.value][key];
//   }
// });

function setLocaleMessages(localeMessages, locale) {
  state.localeMessages[locale] = localeMessages
  state.locale = locale
}

// function setLocale(locale) {
//   state.locale = locale
// }

function $ft(key) {
  const deep_value = (obj, path) =>
    path
      .replace(/\[|\]\.?/g, '.')
      .split('.')
      .filter(s => s)
      .reduce((acc, val) => acc && acc[val], obj)
  return deep_value(this.state.localeMessages[this.state.locale], key)
  // return this.state.localeMessages[this.state.locale][key];
}

export const localiseProvider = readonly({
  $ft,
  state,
  setLocaleMessages,
  // setLocale
})