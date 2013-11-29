App.NodeEntryRoute = Ember.Route.extend

  afterModel: (model, transition) ->
    @transitionTo('index')
