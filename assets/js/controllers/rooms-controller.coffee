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
