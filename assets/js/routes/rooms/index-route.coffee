App.RoomsIndexRoute = Ember.Route.extend

  afterModel: (model, transition) ->
    if ! App.isLoggedIn()
      App.set('continueTransition', transition)
      @transitionTo('login')
    return undefined
