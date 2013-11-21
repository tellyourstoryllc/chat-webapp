#= require ../base-controller-mixin

App.RoomsIndexController = Ember.Controller.extend App.BaseControllerMixin,

  allRooms: (->
    App.Group.all()
  ).property()

  rooms: Ember.computed.filterBy 'allRooms', 'isDeleted', false

  resetNewRoom: ->
    @setProperties
      newRoomName: ''
      createGroupErrorMessage: null

  resetJoinRoom: ->
    @setProperties
      joinCode: ''
      joinRoomErrorMessage: null

  actions:

    createRoom: ->
      name = @get('newRoomName')
      return if Ember.isEmpty(name)

      @set('isCreatingGroup', true)
      properties =
        name: name
      App.Group.createRecord(properties)
      .then (group) =>
        @set('isCreatingGroup', false)
        # Group was created successfully.
        @resetNewRoom()
        @get('target').send('goToRoom', group)
      , (e) =>
        @set('isCreatingGroup', false)
        # Show error message.
        @set('createGroupErrorMessage', e?.error?.message ? "There was an error.  Please try again.")
        throw e

      return undefined

    joinRoom: ->
      joinCode = App.Group.parseJoinCode(@get('joinCode'))
      return if Ember.isEmpty(joinCode)

      @set('isJoiningRoom', true)
      App.get('api').joinGroup(joinCode)
      .then (json) =>
        @set('isJoiningRoom', false)
        if ! json? || json.error?
          @set('joinRoomErrorMessage', json?.error.message ? "There was an error.  Please try again.")
          return

        # Group was joined successfully.
        @resetJoinRoom()
        group = App.Group.loadSingle(json)
        if group?
          group.set('isDeleted', false)
          @get('target').send('goToRoom', group)
      , (xhr) =>
        @set('isJoiningRoom', false)
        # Show error message.
        msg = xhr?.responseJSON?.error?.message
        @set('joinRoomErrorMessage', msg ? "There was an error.  Please try again.")

      return undefined
