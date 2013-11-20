App.ForgotPasswordRoute = Ember.Route.extend

  afterModel: (model, transition) ->
    if App.isLoggedIn()
      @transitionTo('rooms.index')
      return

  setupController: (controller, model) ->
    @_super(arguments...)
    controller.reset?()
