#= require base-controller-mixin

App.RoomsController = Ember.Controller.extend App.BaseControllerMixin,

  allGroups: null
  allOneToOnes: null
  allContacts: null

  activeTab: 'rooms'

  isLoadingContactsPage: false
  contactsPerPage: 50
  contactsOffset: 0
  contactsLoaded: false

  init: ->
    @_super(arguments...)
    # Initialize to empty arrays so computed properties work.
    for key in ['allGroups', 'allOneToOnes'] when ! @get(key)?
      @set(key, [])
    # Force computed properties.
    @get('numUnreadRooms')

  isRoomsTabActive: Ember.computed.equal('activeTab', 'rooms')
  isContactsTabActive: Ember.computed.equal('activeTab', 'contacts')

  rooms: (->
    (@get('allGroups').concat(@get('allOneToOnes'))).filter (room) ->
      room.get('isOpen') && ! room.get('isDeleted')
  ).property('allGroups.@each.isOpen', 'allGroups.@each.isDeleted',
             'allOneToOnes.@each.isOpen', 'allOneToOnes.@each.isDeleted')

  arrangedRooms: (->
    App.RecordArray.create
      content: @get('rooms')
      sortProperties: ['lastActiveAt']
      sortAscending: false
  ).property('rooms')

  arrangedContacts: (->
    App.RecordArray.create
      content: @get('allContacts')
      sortProperties: ['name']
  ).property('allContacts')

  activeRoom: (->
    App.get('currentlyViewingRoom')
  ).property('App.currentlyViewingRoom')

  unreadRooms: Ember.computed.filterBy('rooms', 'isUnread')

  numUnreadRooms: Ember.computed.alias('unreadRooms.length')

  numUnreadRoomsChanged: (->
    numUnreadRooms = @get('numUnreadRooms')
    macgap?.dock.badge = if numUnreadRooms > 0 then "#{numUnreadRooms}" else null

    # Set titlebar title.
    title = App.get('title')
    if numUnreadRooms > 0
      title = "(#{numUnreadRooms}) #{title}"
    $(document).attr('title', title)
  ).observes('numUnreadRooms')

  activeTabChanged: (->
    activeTab = @get('activeTab')
    if activeTab == 'contacts'
      # Let the UI update before loading.
      Ember.run.next @, 'loadContacts'
  ).observes('activeTab')

  loadContacts: ->
    return if @get('isLoadingContactsPage')
    @set('isLoadingContactsPage', true)
    contactsPerPage = @get('contactsPerPage')
    data =
      offset: @get('contactsOffset')
      limit: contactsPerPage
    App.get('api').fetchContacts(data)
    .always =>
      @set('isLoadingContactsPage', false)
    .then (json) =>
      if ! json? || json.error?
        throw json

      instances = App.loadAll(json)
      users = instances.filter (o) -> o instanceof App.User

      # Use the results.
      @get('allContacts').pushObjects(users)
      users.forEach (u) =>
        u.set('isContact', true)

      # Get the next page.
      offset = @get('contactsOffset')
      numResults = users.get('length')
      @set('contactsOffset', offset + numResults)
      if numResults < contactsPerPage
        @set('contactsLoaded', true)
      else
        Ember.run.next @, 'loadContacts'
    .fail App.rejectionHandler

  actions:

    logInWithRoom: ->
      room = @get('activeRoom')
      if room?
        # Auto-join room after logging in.
        App.set('autoJoinAfterLoggingIn', room)

      @transitionToRoute('login')

    addUserContacts: (users) ->
      users = Ember.makeArray(users)
      App.get('api').addUserContacts(users)
      .then (json) =>
        if ! json? || json.error?
          throw json
        @get('allContacts').pushObjects(users)
        users.forEach (u) =>
          u.set('isContact', true)
      .fail App.rejectionHandler

    removeUserContacts: (users) ->
      users = Ember.makeArray(users)
      allContacts = @get('allContacts')
      App.get('api').removeUserContacts(users)
      .then (json) =>
        if ! json || json.error?
          # Rollback.  Order in the list shouldn't matter.
          allContacts.pushObjects(users)
          users.forEach (u) =>
            u.set('isContact', true)
      .fail App.rejectionHandler
      allContacts.removeObjects(users)
      users.forEach (u) =>
        u.set('isContact', false)

    didFocusSendMessageText: ->
      @get('roomsView')?.send('didFocusSendMessageText')
      return undefined

    toggleRoomsSidebar: ->
      @get('roomsView')?.send('toggleRoomsSidebar')
      return undefined

    showRoomsTab: ->
      @set('activeTab', 'rooms')
      return undefined

    showContactsTab: ->
      @set('activeTab', 'contacts')
      return undefined
