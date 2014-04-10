#= require ../base-controller-mixin

App.RoomsViewConversationController = Ember.Controller.extend App.BaseControllerMixin,

  convo: (->
    App.get('currentlyViewingRoom')
  ).property('App.currentlyViewingRoom')

  showMessages: (->
    !! AppConfig.showMessages
  ).property() # AppConfig is plain old JS object that shouldn't change.
