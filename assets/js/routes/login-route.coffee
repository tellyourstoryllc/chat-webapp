App.LoginRoute = Ember.Route.extend

  beforeModel: (transition) ->
    if App.isLoggedIn()
      @transitionTo('rooms.index')
      return
