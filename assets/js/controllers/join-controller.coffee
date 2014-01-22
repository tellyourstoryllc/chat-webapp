#= require base-controller-mixin

App.JoinController = Ember.Controller.extend App.BaseControllerMixin,

  room: null

  actions:

    logInWithRoom: ->
      room = @get('room')
      if room?
        # Auto-join room after logging in.
        App.set('autoJoinAfterLoggingIn', room)

      @transitionToRoute('login')

    didSignUp: ->
      room = @get('room')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      return undefined

    didLogIn: ->
      room = @get('room')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      return undefined
