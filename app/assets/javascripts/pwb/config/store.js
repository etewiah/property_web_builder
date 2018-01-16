const store = new Vuex.Store({
  state: {
    count: 0,
    itemsForDataTable: [{
        id: 1,
        value: true,
        name: 'The Frozen Yogurt',
        calories: 159,
        fat: 6.0,
        carbs: 24,
        protein: 4.0,
        sodium: 87,
        calcium: '14%',
        iron: '1%'
      },
      {
        id: 2,
        value: true,
        name: 'The Ice cream sandwich',
        calories: 237,
        fat: 9.0,
        carbs: 37,
        protein: 4.3,
        sodium: 129,
        calcium: '8%',
        iron: '1%'
      }
    ]

  },
  mutations: {
    increment(state) {
      state.count++
    }
  }
})
