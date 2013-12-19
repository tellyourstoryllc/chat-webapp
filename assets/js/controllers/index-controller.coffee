#= require base-controller-mixin

App.IndexController = Ember.Controller.extend App.BaseControllerMixin, App.JoinMixin,

  isLoadingRoom: false

  userMessage: null

  room: null

  numMembersToShow: 3

  actions:

    logInWithRoom: ->
      room = @get('room')
      if room?
        # Continue to the room after logging in.
        App.set('continueTransitionArgs', ['rooms.room', room.get('id')])

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
