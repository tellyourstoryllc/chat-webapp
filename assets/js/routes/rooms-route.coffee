App.RoomsRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)
    # Stop listening for new messages.
    App.Group.all().forEach (g) -> g.cancelMessagesSubscription()
    # Cancel loading contacts.
    timer = @get('loadContactsTimer')
    Ember.run.cancel(timer) if timer?

  setupController: (controller, model) ->
    # Initialize contacts.  It's possible to access this when logged out.
    if ! App.get('currentUserContacts')?
      App.set('currentUserContacts', App.ContactsSet.create())

    controller.set('allGroups', App.Group.all())
    controller.set('allOneToOnes', App.OneToOne.all())
    if App.isLoggedIn()
      @_fetchAllConversationsAndSubscribe(controller)

      # By this time, conversations should be loaded.
      @_scheduleLoadContacts(controller)

  renderTemplate: (controller, model) ->
    @_super(arguments...)
    # Render the settings-modal template into the application template's modal
    # outlet.
    @render 'settings-modal',
      into: 'application'
      outlet: 'settingsModal'
      view: 'settingsModal'
      controller: 'settingsModal'
    if ! App.isLoggedIn() && ! App.get('isLoggingIn')
      # Logged out.  Show signup form.
      @render 'room-join-signup-modal',
        into: 'application'
        outlet: 'modal'
      controller.set('showRoomsPageOverlay', true)
    else
      controller.set('showRoomsPageOverlay', false)
    return undefined

  _scheduleLoadContacts: (controller) ->
    controller ?= @controllerFor('rooms')
    @set('loadContactsTimer', Ember.run.later(@, '_loadContacts', controller, 30000))

  _loadContacts: (controller) ->
    @set('loadContactsTimer', null)
    controller.loadContacts()

  _uiRooms: ->
    @controllerFor('rooms').get('arrangedRooms')

  _transitionAwayFromRoom: (room) ->
    return unless room == App.get('currentlyViewingRoom')
    # User is viewing the room, so switch view to another room.
    controller = @controllerFor('rooms')
    rooms = controller.get('arrangedRooms')
    index = rooms.indexOf(room)
    if index >= 0
      if index + 1 < rooms.get('length')
        newRoom = rooms.objectAt(index + 1)
        @transitionTo('rooms.room', newRoom)
      else if 0 <= index - 1 < rooms.get('length')
        newRoom = rooms.objectAt(index - 1)
        @transitionTo('rooms.room', newRoom)
      else
        # Transitioning away from the last room; go to the lobby.
        @transitionTo('rooms.index')

  _hideJoinGroupSignupDialog: ->
    controller = @controllerFor('rooms')
    controller.set('showRoomsPageOverlay', false)
    @disconnectOutlet
      outlet: 'modal'
      parentView: 'application'

  _fetchAllConversationsAndSubscribe: (controller = null) ->
    controller ?= @controllerFor('rooms')
    App.get('api').fetchAllConversations()
    .then (rooms) =>
      if rooms?
        controller.set('roomsLoaded', true)
        # Fetch all Conversations after subscribing.
        rooms.forEach (room) =>
          room.subscribeToMessages().then =>
            room.reload()
      return rooms
    .fail App.rejectionHandler

  actions:

    didSignUp: ->
      room = App.get('currentlyViewingRoom')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      @_hideJoinGroupSignupDialog()
      @_fetchAllConversationsAndSubscribe()
      @_scheduleLoadContacts()
      return undefined

    didLogIn: ->
      room = App.get('currentlyViewingRoom')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      @_hideJoinGroupSignupDialog()
      @_fetchAllConversationsAndSubscribe()
      @_scheduleLoadContacts()
      return undefined

    showPreviousRoom: ->
      uiRooms = @_uiRooms()
      room = App.get('currentlyViewingRoom')
      if room?
        index = uiRooms.indexOf(room)
        newIndex = index - 1 if index >= 0
        newIndex = uiRooms.get('length') - 1 if newIndex < 0
      else
        newIndex = uiRooms.get('length') - 1
      if newIndex?
        inst = uiRooms.objectAt(newIndex)
        @transitionTo('rooms.room', inst) if inst?
      return undefined

    showNextRoom: ->
      uiRooms = @_uiRooms()
      room = App.get('currentlyViewingRoom')
      if room?
        index = uiRooms.indexOf(room)
        newIndex = index + 1 if index >= 0
        newIndex = 0 if newIndex >= uiRooms.get('length')
      else
        newIndex = 0
      if newIndex?
        inst = uiRooms.objectAt(newIndex)
        @transitionTo('rooms.room', inst) if inst?
      return undefined

    willLeaveRoom: (room) ->
      @_transitionAwayFromRoom(room)
      return undefined

    closeRoom: (room) ->
      @_transitionAwayFromRoom(room)
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

    showAddContactsDialog: ->
      @render 'add-contacts',
        into: 'application'
        outlet: 'modal'
      Ember.run.schedule 'afterRender', @, ->
        $('.add-contacts-overlay').removeClass('hidden')
        $('.add-contacts-form').addClass('expand-in')
        $('.new-contacts-text').focus()
      return undefined

    hideAddContactsDialog: ->
      $('.add-contacts-overlay').addClass('hidden')
      $('.add-contacts-form').removeClass('expand-in')
      Ember.run.later @, ->
        @disconnectOutlet
          outlet: 'modal'
          parentView: 'application'
      , 500 # After the animation.
      return undefined

    # Trigger this action when you have received new User instances from the
    # server which are contacts.  This handler tracks the User instances as
    # Contacts.
    didAddUserContacts: (users) ->
      users = Ember.makeArray(users)
      App.get('currentUserContacts').addObjects(users)

    showSettings: ->
      @controllerFor('settingsModal').send('show')
      return undefined
