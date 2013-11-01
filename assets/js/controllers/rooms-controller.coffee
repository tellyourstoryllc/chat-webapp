#= require base-controller-mixin

App.RoomsController = Ember.Controller.extend App.BaseControllerMixin,

  rooms: (->
    @get('allRooms').filter (room) ->
      room.get('isOpen') && ! room.get('isDeleted')
  ).property('allRooms.@each.isOpen', 'allRooms.@each.isDeleted')

  activeRoom: (->
    App.get('currentlyViewingRoom')
  ).property('App.currentlyViewingRoom')
