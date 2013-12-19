App.JoinRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)

  model: (params, transition) ->
    params.join_code

  afterModel: (model, transition) ->
    if App.get('isLoggingIn')
      # Save the transition so that if the user logs in in the future, we come
      # back to the join page.
      App.set('continueTransition', transition)
    else if ! App.isLoggedIn()
      joinCode = model
      App.set('joinCodeToShow', joinCode)
      @transitionTo('index')
    return undefined

  setupController: (controller, model) ->
    @_super(arguments...)
    joinCode = model
    controller.set('joinCode', joinCode)
    App.JoinUtil.loadGroupFromJoinCode(controller, joinCode)

    # Try to open the mobile app.
    Ember.run.schedule 'afterRender', @, ->
      App.attemptToOpenMobileApp("/group/join_code/#{joinCode}")
