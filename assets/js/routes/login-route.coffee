App.LoginRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)
    # If we're leaving the login, forget any room we may have started to join.
    App.set('autoJoinAfterLoggingIn', null)

  afterModel: (model, transition) ->
    if App.isLoggedIn()
      @replaceWith('rooms.index')
    return undefined

  setupController: (controller, model) ->
    @_super(arguments...)
    controller.reset?()
