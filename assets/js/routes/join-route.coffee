App.JoinRoute = Ember.Route.extend

  model: (params, transition) ->
    params.join_code

  setupController: (controller, model) ->
    api = App.get('api')
    api.joinGroup(model)
    .then (json) =>
      if json? && ! json.error?
        # Load everything from the response.
        instances = App.loadAll(json, associateGroupMessages: true)
        group = instances.find (o) -> o instanceof App.Group
        if group?
          @transitionTo('rooms.room', group)
      else if json.error
        controller.set('userMessage', json.error)
