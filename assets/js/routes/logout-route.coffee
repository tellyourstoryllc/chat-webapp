App.LogoutRoute = Ember.Route.extend

  setupController: (controller, model) ->
    @_super(arguments...)

    Ember.run.schedule 'afterRender', @, ->
      logOutLocally = =>
        # Delete authentication token and logged in state.
        window.localStorage.removeItem('token')
        App.setProperties
          token: null
          currentUser: null
          _isLoggedIn: false

        # Set the URL and reload the page to clear everything in memory.
        routerLocation = App._getRouter().location
        if routerLocation instanceof Ember.HistoryLocation
          routerLocation.setURL('/login')
        else
          routerLocation.setURL('/')
        window.location.reload(true)

      App.get('api').logout()
      # Log out locally regardless of what the API returns.
      .then(logOutLocally, logOutLocally)
