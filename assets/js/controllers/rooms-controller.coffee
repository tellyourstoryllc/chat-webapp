#= require base-controller-mixin

App.RoomsController = Ember.Controller.extend App.BaseControllerMixin,

  rooms: Ember.computed.filterBy 'allRooms', 'isOpen', true

  activeRoom: (->
    App.get('currentlyViewingRoom')
  ).property('App.currentlyViewingRoom')
