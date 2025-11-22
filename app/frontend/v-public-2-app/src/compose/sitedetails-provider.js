import { reactive, computed, readonly } from "vue";
import loSortBy from "lodash/sortBy"

const state = reactive({
  locale: "es",
  topNavLinkItems: [],
  footerNavLinkItems: [],
  agency: {},
  supportedLocales: []
})

function setTopNavItems(publicLocale, topNavLinks) {
  let topNavLinkItems = setNavItems(publicLocale, topNavLinks)
  state.topNavLinkItems = loSortBy(topNavLinkItems, "sortOrder")
}
function setFooterNavItems(publicLocale, footerNavLinks) {
  let footerNavLinkItems = setNavItems(publicLocale, footerNavLinks)
  state.footerNavLinkItems = loSortBy(footerNavLinkItems, "sortOrder")
}
function setNavItems(publicLocale, navLinks) {
  let navLinkItems = []
  navLinks.forEach((navLink) => {
    // sortOrder,
    //   slug,
    //   linkUrl,
    //   linkPath,
    //   linkPathParams,
    // Have to create a new item below as navLink that is passed in is readonly
    let linkWithRoute = {
      linkTitle: navLink.linkTitle
    }
    if (navLink.linkPath === "admin_with_locale_path") {
      return
    }
    if (navLink.linkPath === "buy_path") {
      linkWithRoute.route = {
        name: "rForSaleSearch",
        params: {
          publicLocale: publicLocale,
        },
      }
    } else if (navLink.linkPath === "rent_path") {
      linkWithRoute.route = {
        name: "rForRentSearch",
        params: {
          publicLocale: publicLocale,
        },
      }
    } else if (navLink.linkPath === "contact_us_path") {
      linkWithRoute.route = {
        name: "rContactUs",
        params: {
          publicLocale: publicLocale,
        },
      }
    } else if (navLink.linkPath === "show_page_path") {
      linkWithRoute.route = {
        name: "rPublicPage",
        params: {
          pageSlug: navLink.linkPathParams,
          publicLocale: publicLocale,
        },
      }
    } else {
      linkWithRoute.route = {
        name: "rLocaleHomePage",
        params: {
          pageSlug: navLink.linkPathParams,
          publicLocale: publicLocale,
        },
      }
    }
    navLinkItems.push(linkWithRoute)
  })
  return navLinkItems
}

function setAgency(agency, supportedLocales) {
  state.agency = agency || {}
  state.supportedLocales = supportedLocales || []
}

export const sitedetailsProvider = readonly({
  setTopNavItems,
  setFooterNavItems,
  setAgency,
  state
})