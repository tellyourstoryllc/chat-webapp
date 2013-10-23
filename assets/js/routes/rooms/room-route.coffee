App.RoomsRoomRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)

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

    # Mark the room as read.
    if model?
      model.set('isUnread', false)

    App.Group.fetchById(groupId)
    .then (json) =>
      if ! json.error?
        # Load everything from the response.
        instances = App.loadAll(json, loadSingleGroup: true)

        # If we landed on this route, this is the first time we have the full
        # Group instance, so set it on the controller.
        if ! model?
          model = instances.find (o) -> o instanceof App.Group
          controller.set('model', model)
          App.set('currentlyViewingRoom', model)
