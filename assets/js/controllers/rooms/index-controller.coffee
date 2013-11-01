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
