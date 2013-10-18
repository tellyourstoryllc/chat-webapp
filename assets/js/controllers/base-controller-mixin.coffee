App.BaseControllerMixin = Ember.Mixin.create

  isLoggedIn: (->
    App.isLoggedIn()
  ).property('App.currentUser')
