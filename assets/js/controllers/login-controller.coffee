App.LoginController = Ember.Controller.extend

  isLoginDisabled: Ember.computed.bool('isChecking')

  actions:

    attemptLogin: ->
      @set('isChecking', true)
      App.get('api').login(@get('email'), @get('password'))
      .then (json) =>
        @set('isChecking', false)

        json = Ember.makeArray(json)

        userJson = json.find (o) -> o.object_type == 'user'
        if userJson.token?
          token = userJson.token
          delete userJson.token

        user = App.User.loadRaw(userJson)
        if token?
          App.login(token, user)
          @transitionTo('index')

      , (e) =>
        @set('isChecking', false)
        throw e
      return undefined
