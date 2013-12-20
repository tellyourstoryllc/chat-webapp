#= require base-controller-mixin

App.RoomsController = Ember.Controller.extend App.BaseControllerMixin,

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

  usersLoaded: (->
    # TODO: Load all contacts.
    room = @get('activeRoom')
    ! room? || room.get('usersLoaded')
  ).property('activeRoom.usersLoaded')

  arrangedMembers: (->
    room = @get('activeRoom')
    if room?
      room.get('arrangedMembers')
    else
      App.User.allArrangedByName()
  ).property('activeRoom.arrangedMembers')

  isActiveRoomOneToOne: (->
    @get('activeRoom') instanceof App.OneToOne
  ).property('activeRoom')

  activeRoomAvatarStyle: (->
    url = @get('activeRoom.avatarUrl')
    return null unless url?
    "background-image: url('#{url}')"
  ).property('activeRoom.avatarUrl')
