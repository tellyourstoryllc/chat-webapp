App.ForgotPasswordRoute = Ember.Route.extend

  afterModel: (model, transition) ->
    if App.isLoggedIn()
      @transitionTo('rooms.index')
    return undefined

  setupController: (controller, model) ->
    @_super(arguments...)
    controller.reset?()
    controller.set('login', App.get('emailAddress') ? '')
