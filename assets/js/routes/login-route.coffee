App.LoginRoute = Ember.Route.extend

  beforeModel: (transition) ->
    if App.isLoggedIn()
      @transitionTo('index')
      return
