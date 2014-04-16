App.RoomsRoute = Ember.Route.extend

  didAttemptFirstFetchAllConversations: false
  fetchingAllConversationsPromise: null

  activate: ->
    @_super(arguments...)

    App.get('eventTarget').on 'didConnect', @, @_didConnect

  deactivate: ->
    @_super(arguments...)
    # Stop listening for new messages.
    App.Group.all().forEach (g) -> g.cancelMessagesSubscription()
    # Cancel loading contacts.
    timer = @get('loadContactsTimer')
    Ember.run.cancel(timer) if timer?
    # Stop listening for reconnect.
    App.get('eventTarget').off 'didConnect', @, @_didConnect

  setupController: (controller, model) ->
    # Initialize contacts.  It's possible to access this when logged out.
    if ! App.get('currentUserContacts')?
      App.set('currentUserContacts', App.ContactsSet.create())

    controller.set('allGroups', App.Group.all())
    controller.set('allOneToOnes', App.OneToOne.all())
    controller.set('allUsers', App.User.all())
    if App.isLoggedIn()
      @_fetchAllConversationsAndContinue(controller)

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
      # @render 'room-join-signup-modal',
      #   into: 'application'
      #   outlet: 'modal'
      # controller.set('showRoomsPageOverlay', true)
      #
      # Instead of showing the signup form overlayed on top of the room, we're
      # going to either show the latest message or redirect depending on config.
    else
      controller.set('showRoomsPageOverlay', false)
    return undefined

  _scheduleLoadContacts: (controller) ->
    controller ?= @controllerFor('rooms')
    @set('loadContactsTimer', Ember.run.later(@, '_loadContacts', controller, 30000))

  _loadContacts: (controller) ->
    @set('loadContactsTimer', null)
    controller.loadContacts() if App.isLoggedIn()

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

  _fetchAllConversationsAndContinue: (controller = null) ->
    controller ?= @controllerFor('rooms')
    @_fetchAllConversationsAndSubscribe()
    .then (rooms) =>
      if rooms?
        controller.set('roomsLoaded', true)

        # Render a few of the most recent rooms.  If we render them all, the
        # page can take a long time to load.
        numRoomsToRender = 5
        arrangedRooms = controller.get('arrangedRooms')
        for i in [0 ... Math.min(arrangedRooms?.get('length') ? 0, numRoomsToRender)] by 1
          room = arrangedRooms.objectAt(i)
          room.ensureMessagesAreRendered()

        continueToMostRecentRoom = App.get('continueToMostRecentRoom')
        # Always consume this flag regardless of whether it was set.
        App.set('continueToMostRecentRoom', false)

        # Prefer a specific room over the most recent room.
        if (room = App.get('continueToRoomWhenReady'))?
          # Always consume this.
          App.set('continueToRoomWhenReady', null)
          # Transition to the room.
          @replaceWith('rooms.room', room)
        else if continueToMostRecentRoom
          # Transition to most recent room.
          room = controller.get('arrangedRooms')?.objectAt(0)
          @replaceWith('rooms.room', room) if room?

      return rooms
    .catch App.rejectionHandler

  _fetchAllConversationsAndSubscribe: ->
    return promise if (promise = @get('fetchingAllConversationsPromise'))?

    @set('didAttemptFirstFetchAllConversations', true)
    promise = App.get('api').fetchAllConversations()
    .always =>
      @set('fetchingAllConversationsPromise', null)
    .then (rooms) =>
      if rooms?
        rooms.forEach (room) =>
          # Fetch all Conversations after subscribing.  As an optimization,
          # don't reload if it's internal.  We basically don't care about those.
          if room.get('isOpen') && ! room.get('isSubscribedToUpdates')
            room.subscribeToMessages().then =>
              room.reload() if ! room.get('isInternal')
          else if ! room.get('reconnectedAt')?
            # Don't subscribe if the room isn't open.  Reload if the room itself
            # hasn't already handled the reconnect.
            Ember.run.next @, ->
              room.reload() if ! room.get('isInternal')
          else
            # Clear reconnectedAt for next time.
            room.set('reconnectedAt', null)

      return rooms
    @set('fetchingAllConversationsPromise', promise)

    promise

  _didConnect: ->
    if ! @get('didAttemptFirstFetchAllConversations')
      # If we're not loaded or not listening, we don't care.
      return

    if App.get('isFayeClientConnected')
      @_didReconnect()

  _didReconnect: ->
    # Make sure we get updated list of conversations if the user joined a room
    # while we were offline.
    @_fetchAllConversationsAndSubscribe()
    .catch App.rejectionHandler

  actions:

    didSignUp: ->
      room = App.get('currentlyViewingRoom')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      @_hideJoinGroupSignupDialog()
      @_fetchAllConversationsAndContinue()
      @_scheduleLoadContacts()
      return undefined

    didLogIn: ->
      room = App.get('currentlyViewingRoom')
      # Just do the default (bubble) if we have no room.
      return true unless room?

      @send('joinGroup', room)
      @_hideJoinGroupSignupDialog()
      @_fetchAllConversationsAndContinue()
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
        # IE hides placeholder text on focus, so don't focus on IE.
        $('.text-input').focus() if ! Modernizr.msie
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

    showJoinRoomDialog: ->
      @render 'join-room',
        into: 'application'
        outlet: 'modal'
        view: 'joinRoomModal'
      Ember.run.schedule 'afterRender', @, ->
        $('.join-room-overlay').removeClass('hidden')
        $('.join-room-form').addClass('expand-in')
        $('.room-key-text').focus()
      return undefined

    hideJoinRoomDialog: ->
      $('.join-room-overlay').addClass('hidden')
      $('.join-room-form').removeClass('expand-in')
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
