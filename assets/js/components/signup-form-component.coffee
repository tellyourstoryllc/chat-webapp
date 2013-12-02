# Actions: didSignUp
App.SignupFormComponent = Ember.Component.extend App.FacebookAuthMixin,

  email: null
  password: null
  name: null

  facebookId: null
  facebookToken: null

  isCreatingUser: false
  isAuthenticatingWithFacebook: false

  isSignupDisabled: Ember.computed.alias('isCreatingUser')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null

  didInsertElement: ->
    @_super(arguments...)

  actions:

    attemptSignUpWithFacebook: ->
      return if @get('isAuthenticatingWithFacebook')

      @setProperties
        isAuthenticatingWithFacebook: true
        errorMessage: null
      @beginSignUpWithFacebookFlow()
      .always =>
        @set('isAuthenticatingWithFacebook', false)
      .then (result) =>
        @setProperties
          email: result.email
          name: [result.firstName, result.lastName].compact().join(' ')
          facebookId: result.facebookId
          facebookToken: result.facebookToken
        @send('attemptSignup')
      , (error) =>
        Ember.Logger.error error, error.stack ? error.stacktrace
        @setProperties
          errorMessage: error?.message ? "There was an error communicating with Facebook.  Please try again."
          # Clear out any facebook credentials that may have been set before.
          facebookId: null
          facebookToken: null

    attemptSignup: ->
      return if @get('isCreatingUser')

      facebookToken = @get('facebookToken')

      password = @get('password') ? ''
      minPasswordLength = App.Account.minPasswordLength()
      if Ember.isEmpty(facebookToken) && password.length < minPasswordLength
        @set('errorMessage', "Password must be at least #{minPasswordLength} characters.")
        return

      @set('isCreatingUser', true)
      @set('errorMessage', null)

      data =
        email: @get('email')
        name: @get('name')
      if Ember.isEmpty(facebookToken)
        data.password = password
      else
        data.facebook_id = @get('facebookId')
        data.facebook_token = facebookToken
      App.get('api').createUser(data)
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
