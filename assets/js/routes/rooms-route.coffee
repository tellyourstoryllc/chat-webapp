App.RoomsRoute = Ember.Route.extend

  deactivate: ->
    # Stop listening for new messages.
    App.Group.all().forEach (g) -> g.cancelMessagesSubscription()

  setupController: (controller, model) ->
    controller.set('allGroups', App.Group.all())
    controller.set('allOneToOnes', App.OneToOne.all())
    App.get('api').fetchAllConversations()
    .then (rooms) =>
      if rooms?
        controller.set('roomsLoaded', true)
        # Fetch all Conversations after subscribing.
        rooms.forEach (room) =>
          room.subscribeToMessages().then =>
            room.reload()
    .fail App.rejectionHandler

  renderTemplate: (controller, model) ->
    @_super(arguments...)
    # Render the settings-modal template into the application template's modal
    # outlet.
    @render 'settings-modal',
      into: 'application'
      outlet: 'settingsModal'
      view: 'settingsModal'
      controller: 'settingsModal'
    return undefined

  _uiRooms: ->
    @controllerFor('rooms').get('arrangedRooms').toArray()

  actions:

    showPreviousRoom: ->
      uiRooms = @_uiRooms()
      index = uiRooms.indexOf(App.get('currentlyViewingRoom'))
      if index >= 0
        index--
        index = uiRooms.length - 1 if index < 0
        inst = uiRooms.objectAt(index)
        @transitionTo('rooms.room', inst)
      return undefined

    showNextRoom: ->
      uiRooms = @_uiRooms()
      index = uiRooms.indexOf(App.get('currentlyViewingRoom'))
      if index >= 0
        index++
        index = 0 if index >= uiRooms.length
        inst = uiRooms.objectAt(index)
        @transitionTo('rooms.room', inst)
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

    showCreateRoomDialog: ->
      @render 'create-room',
        into: 'application'
        outlet: 'modal'
        view: 'createRoomModal'
      Ember.run.schedule 'afterRender', @, ->
        $('.create-room-overlay').removeClass('hidden')
        $('.create-room-form').addClass('expand-in')
        $('.room-name-text').focus()
      return undefined

    hideCreateRoomDialog: ->
      $('.create-room-overlay').addClass('hidden')
      $('.create-room-form').removeClass('expand-in')
      Ember.run.later @, ->
        @disconnectOutlet
          outlet: 'modal'
          parentView: 'application'
      , 500 # After the animation.
      return undefined

    showSettings: ->
      @controllerFor('settingsModal').send('show')
      return undefined
