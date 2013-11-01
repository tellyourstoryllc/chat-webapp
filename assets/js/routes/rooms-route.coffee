App.RoomsRoute = Ember.Route.extend

  deactivate: ->
    # Stop listening for new messages.
    App.Group.all().forEach (g) -> g.cancelMessagesSubscription()

  setupController: (controller, model) ->
    controller.set('allRooms', App.Group.all())
    App.Group.fetchAll()
    .then (groups) =>
      if groups?
        controller.set('roomsLoaded', true)
        for group in groups
          group.subscribeToMessages()

  actions:

    showPreviousRoom: ->
      groups = @controllerFor('rooms').get('rooms')
      index = groups.indexOf(App.get('currentlyViewingRoom'))
      if index >= 0
        index--
        index = groups.length - 1 if index < 0
        @transitionTo('rooms.room', groups[index])
      return undefined

    showNextRoom: ->
      groups = @controllerFor('rooms').get('rooms')
      index = groups.indexOf(App.get('currentlyViewingRoom'))
      if index >= 0
        index++
        index = 0 if index >= groups.length
        @transitionTo('rooms.room', groups[index])
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
