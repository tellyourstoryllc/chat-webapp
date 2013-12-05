App.JoinRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)

  model: (params, transition) ->
    params.join_code

  afterModel: (model, transition) ->
    if ! App.isLoggedIn() || App.get('isLoggingIn')
      # Save the transition so that if the user logs in in the future, we come
      # back to the join page.
      App.set('continueTransition', transition)
    return undefined

  setupController: (controller, model) ->
    @_super(arguments...)
    joinCode = model
    controller.set('joinCode', joinCode)
    @_loadGroupFromJoinCode(controller, joinCode)

    # Try to open the mobile app.
    Ember.run.schedule 'afterRender', @, ->
      App.attemptToOpenMobileApp("/group/join_code/#{joinCode}")

  _loadGroupFromJoinCode: (controller, joinCode) ->
    App.Group.fetchByJoinCode(joinCode)
    .then (json) =>
      if ! json? || json.error?
        controller.set('userMessage', App.userMessageFromError(json))
        return
      # Load everything from the response.
      group = App.Group.loadSingle(json)
      if group?
        group.set('isDeleted', false)
        controller.set('model', group)
        controller.set('room', group)
    , (xhr) =>
      controller.set('userMessage', App.userMessageFromError(xhr))
    .fail App.rejectionHandler
