App.LoginRoute = Ember.Route.extend

  beforeModel: (transition) ->
    if App.isLoggedIn()
      @transitionTo('rooms.index')
      return

  setupController: (controller, model) ->
    @_super(arguments...)
    controller.reset?()
