App.LoginController = Ember.Controller.extend

  isLoginDisabled: Ember.computed.bool('isChecking')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null

  actions:

    attemptLogin: ->
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
            App.login(token, user)
            @transitionToRoute('rooms.index')

      , (e) =>
        @set('isChecking', false)
        @set('errorMessage', "There was an unknown error.  Please try again.")
        throw e
      return undefined
