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
    props: ['dtItems', 'sectionName'],
    data: function() {
      return {
        dialog: false,
        sectionName: "zero",
        rightDrawer: false,
        right: true,
        search: '',
        errText: '',
        pagination: {},
        snackbar: false,
        headers: [{
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
        dtItems: []
      }
    },
    computed: {
      dtItems: {
        get() {
          return this.$store.state.itemsForDataTable || []
        },
        set(value) {
          this.$store.commit('updateDtItems', value)
        }
      }
    },
    mounted: function() {
      // this.sectionName = "one"
      // this.dtItems = []
      // this.getCustomers()
    }
  })

  const fbImport = Vue.component('fb-import', {
    template: '#fb-import',
    firebase: function() {
      return {
        listItems: {
          source: fbDb.ref('client-props'),
          // asObject: true,
          // Optional, allows you to handle any errors.
          cancelCallback(err) {
            console.error(err);
          }
        }
      }
    },
    updated() {
      // debugger
      // a breakpoint here will let me inspect the contents returned from firebase
    }
  })
  const simpleList = Vue.component('simple-list', {
    template: '#simple-list',


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
    mounted() {
      axios.get("/api/v1/agency")
        .then(response => {
          this.listItems = response.data.website.admin_page_links
        })
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
      }
    }


  })
