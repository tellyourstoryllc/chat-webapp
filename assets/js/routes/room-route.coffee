App.RoomRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)
    # Stop listening for new messages.
    @controllerFor('room').cancelMessageSubscription()

  model: (params, transition) ->
    params.group_id

  setupController: (controller, model) ->
    if Ember.typeOf(model) == 'string'
      groupId = model
      model = App.Group.lookup(model)
    else
      groupId = model.get('id')
    @_super(arguments...)

    App.Group.fetchById(groupId)
    .then (json) =>
      if ! json.error?
        instances = App.loadAll(json)
        model.set('messages', instances.filter (o) -> o instanceof App.Message)
        if ! controller.get('subscription')?
          controller.resetMessageSubscription()
