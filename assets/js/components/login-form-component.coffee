# Actions: didLogIn
App.LoginFormComponent = Ember.Component.extend App.FacebookAuthMixin,
  classNames: ['login-form-component']

  facebookId: null
  facebookToken: null

  isLoggingIn: false
  isAuthenticatingWithFacebook: false

  isLoginDisabled: Ember.computed.or('isChecking', 'isLoggingIn')

  errorMessage: null

  didInsertElement: ->
    @_super(arguments...)

  actions:

    attemptLogInWithFacebook: ->
      return if @get('isAuthenticatingWithFacebook')

      @setProperties
        isAuthenticatingWithFacebook: true
        errorMessage: null
      @beginLogInWithFacebookFlow()
      .always =>
        @set('isAuthenticatingWithFacebook', false)
      .then (result) =>
        @setProperties
          facebookId: result.facebookId
          facebookToken: result.facebookToken
        @send('attemptLogin')
      , (error) =>
        Ember.Logger.error error, error.stack ? error.stacktrace
        @setProperties
          errorMessage: error?.message ? "There was an error communicating with Facebook.  Please try again."
          # Clear out any facebook credentials that may have been set before.
          facebookId: null
          facebookToken: null

    attemptLogin: ->
      return if @get('isChecking')
      @set('isChecking', true)
      @set('errorMessage', null)

      if Ember.isEmpty(@get('facebookToken'))
        data =
          email: @get('email')
          password: @get('password')
      else
        data =
          facebook_id: @get('facebookId')
          facebook_token: @get('facebookToken')
      App.get('api').login(data)
      .then (json) =>
        @set('isChecking', false)

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
            @set('isLoggingIn', true)
            App.login(token, user)
            App.whenLoggedIn @, ->
              @set('isLoggingIn', false)
              @sendAction('didLogIn')

      , (xhr) =>
        @set('isChecking', false)
        @set('errorMessage', App.userMessageFromError(xhr))
      .fail App.rejectionHandler
      return undefined
