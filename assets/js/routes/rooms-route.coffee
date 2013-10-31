App.RoomsRoute = Ember.Route.extend

  deactivate: ->
    # Stop listening for new messages.
    App.Group.all().forEach (g) -> g.cancelMessagesSubscription()

  setupController: (controller, model) ->
    controller.set('rooms', App.Group.all())
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
