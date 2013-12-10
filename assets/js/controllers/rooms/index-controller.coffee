#= require ../base-controller-mixin

App.RoomsIndexController = Ember.Controller.extend App.BaseControllerMixin,

  allRooms: (->
    App.Group.all()
  ).property()

  rooms: Ember.computed.filterBy 'allRooms', 'isDeleted', false
