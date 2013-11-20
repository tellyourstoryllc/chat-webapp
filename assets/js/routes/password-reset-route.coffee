App.PasswordResetRoute = Ember.Route.extend

  model: (params, transition) ->
    params.token

  setupController: (controller, model) ->
    @_super(arguments...)
    controller.reset?()
    controller.set('token', model)
