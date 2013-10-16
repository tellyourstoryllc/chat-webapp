App.RoomsRoomRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)
    # Stop listening for new messages.
    @controllerFor('rooms.room').cancelMessageSubscription()

    App.set('currentlyViewingRoom', null)

  beforeModel: (transition) ->
    if ! App.isLoggedIn()
      App.set('continueTransition', transition)
      @transitionTo('login')
      return

  model: (params, transition) ->
    params.group_id

  setupController: (controller, model) ->
    if Ember.typeOf(model) == 'string'
      groupId = model
      model = App.Group.lookup(model)
    else
      groupId = model.get('id')
    @_super(arguments...)

    # Track which room is being viewed so we can determine when to notify the
    # user.
    App.set('currentlyViewingRoom', model)

    App.Group.fetchById(groupId)
    .then (json) =>
      if ! json.error?
        # Load everything from the response.
        instances = App.loadAll(json)

        # If we landed on this route, this is the first time we have the full
        # Group instance, so set it on the controller.
        if ! model?
          model = instances.find (o) -> o instanceof App.Group
          controller.set('model', model)
          App.set('currentlyViewingRoom', model)

        model.set('usersLoaded', true)

        if Ember.isEmpty(model.get('messages'))
          model.set('messages', instances.filter (o) -> o instanceof App.Message)
