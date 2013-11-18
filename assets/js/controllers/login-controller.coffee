App.LoginController = Ember.Controller.extend

  isLoggingIn: false

  isLoginDisabled: Ember.computed.or('isChecking', 'isLoggingIn')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null

  actions:

    attemptLogin: ->
      return if @get('isChecking')
      @set('isChecking', true)
      @set('errorMessage', null)

      App.get('api').login(@get('email'), @get('password'))
      .then (json) =>
        @set('isChecking', false)

        if ! json? || json.error?
          @set('errorMessage', json.error.message)
        else
          json = Ember.makeArray(json)

          userJson = json.find (o) -> o.object_type == 'user'
          if userJson.token?
            token = userJson.token
            delete userJson.token

          user = App.User.loadRaw(userJson)
          if token?
            @set('isLoggingIn', true)
            App.login(token, user)
            App.whenLoggedIn @, ->
              @transitionToRoute('rooms.index')
              @set('isLoggingIn', false)

      , (e) =>
        @set('isChecking', false)
        @set('errorMessage', "There was an unknown error.  Please try again.")
        throw e
      return undefined
