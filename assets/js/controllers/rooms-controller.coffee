#= require base-controller-mixin

App.RoomsController = Ember.Controller.extend App.BaseControllerMixin,

  allGroups: null
  allOneToOnes: null
  allUsers: null

  activeTab: 'rooms'

  isLoadingContactsPage: false
  contactsPerPage: 50
  contactsOffset: 0
  contactsLoaded: false

  displayRooms: null
  oldDisplayRoomsLimit: 0
  displayRoomsLimit: 20

  init: ->
    @_super(arguments...)
    # Initialize to empty arrays so computed properties work.
    for key in ['allGroups', 'allOneToOnes', 'displayRooms'] when ! @get(key)?
      @set(key, [])
    # Force computed properties.
    @get('numUnreadRooms')
    @get('sortedRooms')

  allContacts: (->
    App.get('currentUserContacts')
  ).property('App.currentUserContacts')

  displayContacts: Ember.computed.filterBy('allUsers', 'isInternal', false)

  isRoomsTabActive: Ember.computed.equal('activeTab', 'rooms')
  isContactsTabActive: Ember.computed.equal('activeTab', 'contacts')

  # Note: Not including groups since they are all internal.
  rooms: Ember.computed.filter 'allOneToOnes.@each.{isInternal,isOpen,isDeleted}', (room) ->
    ! room.get('isInternal') && room.get('isOpen') && ! room.get('isDeleted')

  sortedRooms: (->
    App.RecordArray.create
      content: @get('rooms')
      sortProperties: ['lastActiveAt']
      sortAscending: false
  ).property('rooms')

  displayRooms: Ember.arrayComputed 'sortedRooms', 'displayRoomsLimit',
    addedItem: (array, item, changeMeta, instanceMeta) ->
      i = changeMeta.index
      limit = @get('displayRoomsLimit')
      if i < limit
        array.insertAt(i, item)
      len = array.get('length')
      if len > limit
        convo = array.popObject()
      return array
    removedItem: (array, item, changeMeta, instanceMeta) ->
      i = changeMeta.index
      if array.get('length') > i
        array.removeAt(i, 1)
      return array

  displayRoomsLimitWillChange: (->
    @set('oldDisplayRoomsLimit', @get('displayRoomsLimit'))
  ).observesBefore('displayRoomsLimit')

  # When we show more rooms, make sure they're loaded so they can display.
  displayRoomsLimitChanged: (->
    sortedRooms = @get('sortedRooms')
    displayRooms = @get('displayRooms')
    # Limit only ever increases.
    for i in [@get('oldDisplayRoomsLimit') ... @get('displayRoomsLimit')] by 1
      room = sortedRooms.objectAt(i)
      continue unless room?
      displayRooms.pushObject(room)
      room.ensureDisplayableInList()
    undefined
  ).observes('displayRoomsLimit')

  arrangedContacts: (->
    App.RecordArray.create
      content: @get('displayContacts')
      sortProperties: ['name']
  ).property('displayContacts')

  activeRoom: (->
    App.get('currentlyViewingRoom')
  ).property('App.currentlyViewingRoom')

  unreadRooms: Ember.computed.filterBy('rooms', 'isUnread')

  numUnreadRooms: Ember.computed.alias('unreadRooms.length')

  numUnreadRoomsChanged: (->
    numUnreadRooms = @get('numUnreadRooms')
    macgap?.dock.badge = if numUnreadRooms > 0 then "#{numUnreadRooms}" else null

    # Set titlebar title.
    title = App.get('documentTitle')
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
    return if @get('isLoadingContactsPage') || @get('contactsLoaded')
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
      @get('allContacts').addObjects(users)

      # Get the next page.
      offset = @get('contactsOffset')
      numResults = users.get('length')
      @set('contactsOffset', offset + numResults)
      if numResults < contactsPerPage
        @set('contactsLoaded', true)
      else
        Ember.run.next @, 'loadContacts'
    .catch App.rejectionHandler

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
        @get('allContacts').addObjects(users)
      .catch App.rejectionHandler

    removeUserContacts: (users) ->
      users = Ember.makeArray(users)
      allContacts = @get('allContacts')
      App.get('api').removeUserContacts(users)
      .then (json) =>
        if ! json || json.error?
          # Rollback.  Order in the list shouldn't matter.
          allContacts.addObjects(users)
      .catch App.rejectionHandler
      allContacts.removeObjects(users)

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
