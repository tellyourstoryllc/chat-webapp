App.SignupController = Ember.Controller.extend

  isSignupDisabled: Ember.computed.bool('isCreatingUser')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null

  actions:

    attemptSignup: ->
      return if @get('isCreatingUser')
      @set('isCreatingUser', true)
      @set('errorMessage', null)

      App.get('api').createUser(@get('email'), @get('password'), @get('name'))
      .then (json) =>
        @set('isCreatingUser', false)

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
        @set('isCreatingUser', false)
        @set('errorMessage', "There was an unknown error.  Please try again.")
        throw e
      return undefined
