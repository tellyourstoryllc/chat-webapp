App.RoomsRoute = Ember.Route.extend

  beforeModel: (transition) ->
    if ! App.isLoggedIn()
      App.set('continueTransition', transition)
      @transitionTo('login')
      return

  setupController: (controller, model) ->
    controller.set('rooms', App.Group.all())
    App.Group.fetchAll()
    .then (groups) =>
      if groups?
        controller.set('roomsLoaded', true)
        for group in groups
          group.subscribeToMessages()
