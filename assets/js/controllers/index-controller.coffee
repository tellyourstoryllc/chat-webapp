#= require base-controller-mixin

App.IndexController = Ember.Controller.extend App.BaseControllerMixin, App.JoinMixin,

  isLoadingRoom: false

  userMessage: null

  room: null

  numMembersToShow: 3

  joinCodeToShow: null

  # Used by the mobile-install template.
  joinCode: Ember.computed.alias('joinCodeToShow')

  needsMacApp: (->
    # If we're already running in the app, don't show the download stuff.
    return false if macgap?

    matches = /Mac OS X 10_(\d+)_/i.exec(navigator.userAgent)
    return false if ! matches?
    minor = parseInt(matches[1])

    minor? && ! _.isNaN(minor) && minor >= 8
  ).property()

  joinGroupNow: (room) ->
    @get('target').send('joinGroup', room)

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

      @joinGroupNow(room)
      return undefined

    # It's possible to log in on the home page using facebook.
    didLogIn: ->
      room = @get('room')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @joinGroupNow(room)
      return undefined
