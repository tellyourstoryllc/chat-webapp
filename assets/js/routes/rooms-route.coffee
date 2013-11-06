App.RoomsRoute = Ember.Route.extend

  deactivate: ->
    # Stop listening for new messages.
    App.Group.all().forEach (g) -> g.cancelMessagesSubscription()

  setupController: (controller, model) ->
    controller.set('allGroups', App.Group.all())
    controller.set('allOneToOnes', App.OneToOne.all())
    App.Group.fetchAll()
    .then (groups) =>
      if groups?
        controller.set('roomsLoaded', true)
        for group in groups
          group.subscribeToMessages()

  # Returns a pair where the first is a list representing the rooms list in the
  # UI, and the second is the lobby object.
  _uiGroups: ->
    # Create a list that includes the lobby in the first position to match the
    # UI.
    groups = @controllerFor('rooms').get('rooms')
    lobby = Ember.Object.create
      transitionToArgs: ['rooms.index']
    uiGroups = groups.copy()
    uiGroups.unshiftObject(lobby)

    [uiGroups, lobby]

  actions:

    showPreviousRoom: ->
      [uiGroups, lobby] = @_uiGroups()
      index = uiGroups.indexOf(App.get('currentlyViewingRoom') ? lobby)
      if index >= 0
        index--
        index = uiGroups.length - 1 if index < 0
        inst = uiGroups.objectAt(index)
        if inst instanceof App.Group
          @transitionTo('rooms.room', inst)
        else
          @transitionTo(inst.get('transitionToArgs')...)
      return undefined

    showNextRoom: ->
      [uiGroups, lobby] = @_uiGroups()
      index = uiGroups.indexOf(App.get('currentlyViewingRoom') ? lobby)
      if index >= 0
        index++
        index = 0 if index >= uiGroups.length
        inst = uiGroups.objectAt(index)
        if inst instanceof App.Group
          @transitionTo('rooms.room', inst)
        else
          @transitionTo(inst.get('transitionToArgs')...)
      return undefined

    closeRoom: (room) ->
      controller = @controllerFor('rooms')
      if room == App.get('currentlyViewingRoom')
        # User is viewing the room, so switch view to another room.
        rooms = controller.get('rooms')
        index = rooms.indexOf(room)
        if index >= 0
          if index + 1 < rooms.length
            newRoom = rooms.objectAt(index + 1)
            @transitionTo('rooms.room', newRoom)
          else if 0 <= index - 1 < rooms.length
            newRoom = rooms.objectAt(index - 1)
            @transitionTo('rooms.room', newRoom)
          else
            # Closing the last room; go to the lobby.
            @transitionTo('rooms.index')

      room.set('isOpen', false)
      return undefined
