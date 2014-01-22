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
