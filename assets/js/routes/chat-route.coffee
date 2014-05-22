App.ChatRoute = Ember.Route.extend

  model: (params, transition) ->
    params.group_id

  setupController: (controller, model) ->
    @_super(arguments...)

    # Track in MixPanel.
    App.get('api').logEvent(event_name: 'clicked_invite_link')
    # TODO: mobile install dialog component is redirecting.  Wait until this
    # call completes.
