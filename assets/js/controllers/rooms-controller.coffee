#= require base-controller-mixin

App.RoomsController = Ember.Controller.extend App.BaseControllerMixin,

  allGroups: null
  allOneToOnes: null

  init: ->
    @_super(arguments...)
    # Initialize to empty arrays so computed properties work.
    for key in ['allGroups', 'allOneToOnes'] when ! @get(key)?
      @set(key, [])
    # Force computed properties.
    @get('numUnreadRooms')

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

  actions:

    didFocusSendMessageText: ->
      @get('roomsView')?.send('didFocusSendMessageText')
      return undefined

    toggleRoomsSidebar: ->
      @get('roomsView')?.send('toggleRoomsSidebar')
      return undefined
