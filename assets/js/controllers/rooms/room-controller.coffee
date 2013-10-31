#= require ../base-controller-mixin

App.RoomsRoomController = Ember.ObjectController.extend App.BaseControllerMixin,
  needs: ['rooms']

  room: Ember.computed.alias('content')

  roomsLoaded: (->
    @get('controllers.rooms.roomsLoaded')
  ).property('controllers.rooms.roomsLoaded')
