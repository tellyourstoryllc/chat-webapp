App.IndexRoute = Ember.Route.extend

  beforeModel: (transition) ->
    if ! App.isLoggedIn()
      @transitionTo('login')
      return
