#= require base-controller-mixin

App.JoinController = Ember.Controller.extend App.BaseControllerMixin,

  showMobileInstall: false
  joinCode: null
  room: null

  userMessage: null
  isLoading: false
  isSignupDisabled: false

  reset: ->
    @setProperties
      userMessage: null
      isLoading: false
      isSignupDisabled: false

  actions:

    didDismissMobileInstallDialog: ->
      @set('showMobileInstall', false)
      return undefined

    logInWithRoom: ->
      room = @get('room')
      if room?
        # Auto-join room after logging in.
        App.set('autoJoinAfterLoggingIn', room)

      @transitionToRoute('login')

    didSignUp: ->
      # Disable the signup UI.
      @set('isSignupDisabled', true)

      room = @get('room')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      return undefined

    didLogIn: ->
      # Disable the signup UI.
      @set('isSignupDisabled', true)

      room = @get('room')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      return undefined
