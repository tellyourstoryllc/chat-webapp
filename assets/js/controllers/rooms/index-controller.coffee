#= require ../base-controller-mixin

App.RoomsIndexController = Ember.Controller.extend App.BaseControllerMixin,
  needs: ['rooms']

  roomsLoaded: (->
    @get('controllers.rooms.roomsLoaded')
  ).property('controllers.rooms.roomsLoaded')

  allRooms: (->
    App.Group.all()
  ).property()

  rooms: Ember.computed.filterBy 'allRooms', 'isDeleted', false

  showCreateRoomCallout: (->
    @get('roomsLoaded') && Ember.isEmpty(@get('rooms'))
  ).property('roomsLoaded', 'rooms.[]')
