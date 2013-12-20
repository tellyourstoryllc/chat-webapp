#= require base-controller-mixin

App.IndexController = Ember.Controller.extend App.BaseControllerMixin, App.JoinMixin,

  isLoadingRoom: false

  userMessage: null

  room: null

  numMembersToShow: 3

  joinCodeToShow: null

  # Used by the mobile-install template.
  joinCode: Ember.computed.alias('joinCodeToShow')

  actions:

    logInWithRoom: ->
      room = @get('room')
      if room?
        # Auto-join room after logging in.
        App.set('autoJoinAfterLoggingIn', room)

      @transitionToRoute('login')

    clearJoinRoom: ->
      @set('room', null)
      @set('userMessage', null)
      return undefined

    joinRoom: (roomKey) ->
      # Clear out old room.
      @set('room', null)

      @set('isLoadingRoom', true)
      App.JoinUtil.loadGroupFromJoinCode(@, roomKey)
      .always =>
        @set('isLoadingRoom', false)
      return undefined

    didSignUp: ->
      room = @get('room')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      # Join the room.
      @get('target').send('joinGroup', room.get('joinCode') ? room.get('id'))

      return undefined
