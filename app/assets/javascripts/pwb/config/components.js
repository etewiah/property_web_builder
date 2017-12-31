  Vue.component('about-page', {
    template: '#about-page',
    data: function() {
      return {
        dialog: false,

      }
    }
  })




  Vue.component('simple-form', {
    template: '#simple-form',
    // props: ['items'],
    data: function() {
      return {
        dialog: false,

      rightDrawer: false,
      right: true,
      search: '',
      errText: '',
      pagination: {},
      snackbar: false,
        headers: [
          {
            text: 'Dessert (100g serving)',
            align: 'left',
            sortable: false,
            value: 'name'
          },
          { text: 'Calories', value: 'calories' },
          { text: 'Fat (g)', value: 'fat' },
          { text: 'Carbs (g)', value: 'carbs' },
          { text: 'Protein (g)', value: 'protein' },
          { text: 'Sodium (mg)', value: 'sodium' },
          { text: 'Calcium (%)', value: 'calcium' },
          { text: 'Iron (%)', value: 'iron' }
        ],
        items: [
          {
            value: false,
            name: 'Frozen Yogurt',
            calories: 159,
            fat: 6.0,
            carbs: 24,
            protein: 4.0,
            sodium: 87,
            calcium: '14%',
            iron: '1%'
          },
          {
            value: false,
            name: 'Ice cream sandwich',
            calories: 237,
            fat: 9.0,
            carbs: 37,
            protein: 4.3,
            sodium: 129,
            calcium: '8%',
            iron: '1%'
          }
        ]
      }
    },
    computed: {},
    mounted: function() {
      // debugger
      // this.getCustomers()
    }
  })    

  const simpleList = Vue.component('simple-list', {
    template: '#simple-list',
  //   data: function() {
  //     return {
  //       dialog: false,

  //     }
  //   }
  // })

  // Vue.component('simple-form', {
  //   template: '#simple-form',
    data: function() {
      return {
        props: null,
       listItems: [
          { header: 'Today' },
          { avatar: '/static/doc-images/lists/1.jpg', title: 'Brunch this weekend?', subtitle: "<span class='grey--text text--darken-2'>Ali Connors</span> — I'll be in your neighborhood doing errands this weekend. Do you want to hang out?" },
          { divider: true, inset: true },
          { avatar: '/static/doc-images/lists/2.jpg', title: 'Summer BBQ <span class="grey--text text--lighten-1">4</span>', subtitle: "<span class='grey--text text--darken-2'>to Alex, Scott, Jennifer</span> — Wish I could come, but I'm out of town this weekend." },
          { divider: true, inset: true },
          { avatar: '/static/doc-images/lists/3.jpg', title: 'Oui oui', subtitle: "<span class='grey--text text--darken-2'>Sandra Adams</span> — Do you have Paris recommendations? Have you ever been?" }
        ],


        props: [],
        rightDrawer: false,
        right: true,
        search: '',
        errText: 'ttt',
        pagination: {},
        snackbar: false,
        headers: [{
            text: 'First Name',
            left: true,
            sortable: false,
            value: 'firstName'
          },
          { text: 'Last Name', value: 'lastName' },
          { text: 'Email', value: 'email' },
          { text: 'Age', value: 'age' },
          { text: 'Order Record', value: 'orderRecord' },
          { text: 'Active', value: 'isActive' },
          { text: '', value: '' }
        ],
        searchVm: {
          contains: {
            firstName: '',
            lastName: ''
          },
          between: {
            age: { former: 0, latter: 0 }
          }
        }
      }
    },
    methods: {
      print() {
        window.print()
      },
      edit(item) {
        this.$router.push({ name: 'Customer', params: { id: item.id } })
      },
      add() {
        this.$router.push('NewCustomer')
      },
      remove(item) {

        this.$parent.openDialog('Do you want to delete this item?', '', () => {
          this.api.deleteData('customers/' + item.id.toString()).then((res) => {
            this.getCustomers()
          }, (err) => {
            console.log(err)
            this.snackbar = true
            this.errText = 'Status has not be deleted successfully. Please try again.'
          })
        })
      },
      changeStatus(item) {
        item.isActive = !item.isActive
        this.api.putData('customers/' + item.id.toString(), item).then((res) => {
          // this.$router.push('Customers')
        }, (err) => {
          console.log(err)
          this.snackbar = true
          this.errText = 'Status has not be updated successfully. Please try again.'
          item.isActive = !item.isActive
        })
      },
      searchCustomers() {
        this.rightDrawer = !this.rightDrawer
        this.appUtil.buildSearchFilters(this.searchVm)
        let query = this.appUtil.buildJsonServerQuery(this.searchVm)

        this.api.getData('customers?' + query).then((res) => {

          this.items = res.data
          this.items.forEach((item) => {
            if (item.orders && item.orders.length) {
              item.orderRecord = item.orders.length
            } else {
              item.orderRecord = 0
            }
          })
        }, (err) => {
          console.log(err)
        })
      },
      clearSearchFilters() {

        this.rightDrawer = !this.rightDrawer
        this.appUtil.clearSearchFilters(this.searchVm)

        this.api.getData('customers').then((res) => {
          this.items = res.data
          this.items.forEach((item) => {
            if (item.orders && item.orders.length) {
              item.orderRecord = item.orders.length
            } else {
              item.orderRecord = 0
            }
          })
          console.log(this.items)
        }, (err) => {
          console.log(err)
        })
      },
      getCustomers() {
        // this.api.getData('customers?_embed=orders').then((res) => {
        //   this.items = res.data
        //   this.items.forEach((item) => {
        //     // item.avatar = '/assets/' + item.avatar
        //     if (item.orders && item.orders.length) {
        //       item.orderRecord = item.orders.length
        //     } else {
        //       item.orderRecord = 0
        //     }
        //   })
        // }, (err) => {
        //   console.log(err)
        // })
      }
    }


  })
