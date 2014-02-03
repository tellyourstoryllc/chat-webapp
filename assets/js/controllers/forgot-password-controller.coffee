App.ForgotPasswordController = Ember.Controller.extend

  login: ''

  hasSentResetEmail: false

  isRequesting: false

  isSendDisabled: Ember.computed.alias('isRequesting')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null
      hasSentResetEmail: false

  loginChanged: (->
    login = @get('login')
    if login? && login.indexOf('@') >= 0 && login != App.get('emailAddress')
      App.set('emailAddress', login)
  ).observes('login')

  actions:

    sendPasswordResetEmail: ->
      return if @get('isRequesting')
      @set('isRequesting', true)
      @set('errorMessage', null)

      App.get('api').sendPasswordResetEmail(@get('login'))
      .always =>
        @set('isRequesting', false)
      .then (json) =>
        if ! json? || json.error?
          @set('errorMessage', App.userMessageFromError(json))
        else
          # Assume success.
          @set('hasSentResetEmail', true)
      , (xhr) =>
        @set('errorMessage', App.userMessageFromError(xhr))
      .fail App.rejectionHandler
      return undefined
