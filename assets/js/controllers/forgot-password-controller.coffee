App.ForgotPasswordController = Ember.Controller.extend

  hasSentResetEmail: false

  isRequesting: false

  isSendDisabled: Ember.computed.alias('isRequesting')

  errorMessage: null

  reset: ->
    @setProperties
      errorMessage: null
      hasSentResetEmail: false

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
          @set('errorMessage', json?.error?.message ? "There was an unknown error.  Please try again.")
        else
          # Assume success.
          @set('hasSentResetEmail', true)
      , (xhr) =>
        @set('errorMessage', xhr.responseJSON?.error?.message ? "There was an unknown error.  Please try again.")
      .fail App.rejectionHandler
      return undefined
