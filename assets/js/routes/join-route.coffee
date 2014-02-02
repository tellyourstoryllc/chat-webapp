App.JoinRoute = Ember.Route.extend

  model: (params, transition) ->
    params.join_code

  afterModel: (model, transition) ->
    if App.get('isLoggingIn')
      # Save the transition so that if the user logs in in the future, we come
      # back to the join page.
      App.set('continueTransition', transition)
      @replaceWith('login')
    return undefined

  setupController: (controller, model) ->
    @_super(arguments...)
    controller.reset?()
    joinCode = model
    controller.set('joinCode', joinCode)
    controller.set('room', null)
    @_submitRoomKey(controller)

  _submitRoomKey: (controller, roomKeyText) ->
    controller ?= @controllerFor('join')
    joinCode = roomKeyText ? controller.get('joinCode')

    controller.set('isLoading', true)
    controller.set('userMessage', null)
    App.Group.fetchByJoinCode(joinCode)
    .always =>
      controller.set('isLoading', false)
    .then (json) =>
      group = App.Group.loadSingle(json)
      controller.set('room', group)
      if group?
        if App.isLoggedIn()
          @send('goToRoom', group)
        else if App.get('isLoggingIn')
          App.set('continueTransitionArgs', ['rooms.room', group])
    , (xhr) =>
      msg = "There was a problem.  Please try again later." if 500 <= xhr.status <= 599
      msg ?= "Sorry, that room couldn't be found."
      controller.set('userMessage', msg)

  actions:

    submitRoomKey: (roomKeyText) ->
      @_submitRoomKey(null, roomKeyText)
      return undefined
