App.JoinRoute = Ember.Route.extend

  activate: ->
    @_super(arguments...)
    @controllerFor('application').set('doNotShowLoginSignup', true)

  deactivate: ->
    @_super(arguments...)
    @controllerFor('application').set('doNotShowLoginSignup', false)

  model: (params, transition) ->
    params.join_code

  afterModel: (model, transition) ->
    if App.get('isLoggingIn')
      # Save the transition so that if the user logs in in the future, we come
      # back to the join page.
      App.set('continueTransition', transition)
    return undefined

  setupController: (controller, model) ->
    @_super(arguments...)
    joinCode = model
    controller.set('joinCode', joinCode)
    controller.set('isLoading', true)
    App.Group.fetchByJoinCode(joinCode)
    .always =>
      controller.set('isLoading', false)
    .then (json) =>
      group = App.Group.loadSingle(json)
      if App.isLoggedIn() && group?.get('isCurrentUserMember')
        @send('goToRoom', group)
    , (xhr) =>
      msg = "There was a problem.  Please try again later." if 500 <= xhr.status <= 599
      msg ?= "Sorry, that room couldn't be found."
      controller.set('userMessage', msg)
