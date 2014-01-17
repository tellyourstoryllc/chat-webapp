# Actions: didSignUp, didLogIn, didClose, facebookDidError
App.SignupFormComponent = Ember.Component.extend App.FacebookAuthMixin,
  classNames: ['signup-form-component']

  shouldRequirePassword: true

  email: null
  password: null
  name: null

  facebookId: null
  facebookToken: null
  avatarImageUrl: null

  isCreatingUser: false
  isLoggingIn: false
  isAuthenticatingWithFacebook: false

  isSignupDisabled: Ember.computed.or('isCheckingLogIn', 'isCreatingUser', 'isLoggingIn')

  errorMessage: null
  facebookErrorMessage: null
  userErrorMessage: Ember.computed.any('errorMessage', 'facebookErrorMessage')

  reset: ->
    @setProperties
      errorMessage: null

  didInsertElement: ->
    @_super(arguments...)

  showClose: Ember.computed.alias('didClose')

  actions:

    close: ->
      @sendAction('didClose')
      return undefined

    dismissErrorMessage: ->
      @set('errorMessage', null)
      return undefined

    attemptSignUpWithFacebook: ->
      return if @get('isAuthenticatingWithFacebook')

      @setProperties
        isAuthenticatingWithFacebook: true
        errorMessage: null
        facebookErrorMessage: null
      @beginSignUpWithFacebookFlow()
      .always =>
        @set('isAuthenticatingWithFacebook', false)
      .then (result) =>
        @setProperties
          email: result.email
          name: [result.firstName, result.lastName].compact().join(' ')
          facebookId: result.facebookId
          facebookToken: result.facebookToken
          avatarImageUrl: result.avatarImageUrl

        if window.localStorage.getItem('skipFacebookLoginCheck') in ['1', 'true']
          # For debugging facebook signup.  Don't try to log in after
          # authenticating with facebook.
          @send('attemptSignup')
        else
          @send('attemptLogInWithFacebookOrSignup')
      , (error) =>
        Ember.Logger.error error, error.stack ? error.stacktrace
        @setProperties
          facebookErrorMessage: error?.message ? "There was an error communicating with Facebook.  Please try again."
          # Clear out any facebook credentials that may have been set before.
          facebookId: null
          facebookToken: null
          avatarImageUrl: null
        @sendAction('facebookDidError', error)

    attemptLogInWithFacebookOrSignup: ->
      return if @get('isCheckingLogIn')
      @set('isCheckingLogIn', true)
      @set('errorMessage', null)
      @set('facebookErrorMessage', null)

      data =
        facebook_id: @get('facebookId')
        facebook_token: @get('facebookToken')
      App.get('api').login(data)
      .always =>
        @set('isCheckingLogIn', false)
      .then (json) =>
        if ! json? || json.error?
          # Ignore error; just fall back to signing up.
          @send('attemptSignup')
          return

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
        else
          # This should never happen, but if it does, just fall back to signing
          # up.
          @send('attemptSignup')

      , (xhr) =>
        # Ignore error; just fall back to signing up.
        @send('attemptSignup')
      .fail App.rejectionHandler
      return undefined

    attemptSignup: ->
      return if @get('isCreatingUser')

      email = @get('email')
      name = @get('name')

      # Signup validation.
      if Ember.isEmpty(email)
        @set('errorMessage', "Email address is required.")
        return

      if Ember.isEmpty(name)
        @set('errorMessage', "Display name is required.")
        return

      facebookToken = @get('facebookToken')

      password = @get('password') ? ''
      minPasswordLength = App.Account.minPasswordLength()
      if @get('shouldRequirePassword') && Ember.isEmpty(facebookToken) && password.length < minPasswordLength
        @set('errorMessage', "Password must be at least #{minPasswordLength} characters.")
        return

      @set('isCreatingUser', true)
      @set('errorMessage', null)

      data =
        email: email
        name: name
      if Ember.isEmpty(facebookToken)
        data.password = password
      else
        data.facebook_id = @get('facebookId')
        data.facebook_token = facebookToken
        data.avatar_image_url = @get('avatarImageUrl')
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
            @set('isLoggingIn', true)
            App.login(token, user)
            App.whenLoggedIn @, ->
              @set('isLoggingIn', false)
              @sendAction('didSignUp')

      , (xhr) =>
        @set('isCreatingUser', false)
        @set('errorMessage', App.userMessageFromError(xhr))
      .fail App.rejectionHandler
      return undefined
