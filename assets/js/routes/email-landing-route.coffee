App.EmailLandingRoute = Ember.Route.extend

  setupController: (controller, model) ->
    @_super(arguments...)

    # Track in MixPanel.
    App.get('api').logEvent(event_name: 'clicked_invite_link')
    # TODO: mobile install dialog component is redirecting.  Wait until this
    # call completes.

  renderTemplate: (controller, model) ->
    @render 'email-landing'
