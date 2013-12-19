#= require base-controller-mixin

App.IndexController = Ember.Controller.extend App.BaseControllerMixin, App.JoinMixin,

  isLoadingRoom: false

  userMessage: null

  room: null

  numMembersToShow: 3

  actions:

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
