App.PasswordResetController = Ember.Controller.extend

  # The token from the URL in the reset email.
  token: null

  hasReset: false

  isRequesting: false

  isSendDisabled: Ember.computed.alias('isRequesting')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null
      hasReset: false

  actions:

    resetPassword: ->
      return if @get('isRequesting')

      newPassword = @get('newPassword') ? ''
      minPasswordLength = App.Account.minPasswordLength()
      if newPassword.length < minPasswordLength
        @set('errorMessage', "Password must be at least #{minPasswordLength} characters.")
        return

      @set('isRequesting', true)
      @set('errorMessage', null)

      App.get('api').resetPassword(@get('token'), newPassword)
      .always =>
        @set('isRequesting', false)
      .then (json) =>
        if ! json? || json.error?
          @set('errorMessage', App.userMessageFromError(json))
        else
          # Assume success.
          @set('hasReset', true)
      , (xhr) =>
        @set('errorMessage', App.userMessageFromError(xhr))
      .catch App.rejectionHandler
      return undefined
