# Actions: didSignUp
App.SignupFormComponent = Ember.Component.extend

  email: null
  password: null
  name: null

  isSignupDisabled: Ember.computed.bool('isCreatingUser')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null

  actions:

    attemptSignup: ->
      return if @get('isCreatingUser')

      password = @get('password') ? ''
      minPasswordLength = App.Account.minPasswordLength()
      if password.length < minPasswordLength
        @set('errorMessage', "Password must be at least #{minPasswordLength} characters.")
        return

      @set('isCreatingUser', true)
      @set('errorMessage', null)

      App.get('api').createUser(@get('email'), password, @get('name'))
      .then (json) =>
        @set('isCreatingUser', false)

        if ! json? || json.error?
          @set('errorMessage', App.userMessageFromError(json))
        else
          json = Ember.makeArray(json)

          userJson = json.find (o) -> o.object_type == 'user'
          if userJson.token?
            token = userJson.token
            delete userJson.token

          user = App.User.loadRaw(userJson)
          if token?
            App.login(token, user)
            @sendAction('didSignUp')

      , (xhr) =>
        @set('isCreatingUser', false)
        @set('errorMessage', App.userMessageFromError(xhr))
      .fail App.rejectionHandler
      return undefined
