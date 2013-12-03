App.JoinRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)
    # If we're listening for the login and transition away, stop listening.
    App.get('eventTarget').off 'didLogIn', @, '_didLogIn'

  beforeModel: (transition) ->
    # This should work when landing on this URL, so allow when we're in the
    # process of logging in.
    if ! App.isLoggedIn() && ! App.get('isLoggingIn')
      App.set('continueTransition', transition)
      @transitionTo('login')
      return

  model: (params, transition) ->
    params.join_code

  setupController: (controller, model) ->
    @_super(arguments...)
    joinCode = model
    App.whenLoggedIn @, ->
      api = App.get('api')
      api.joinGroup(joinCode)
      .then (json) =>
        if json? && ! json.error?
          # Load everything from the response.
          group = App.Group.loadSingle(json)
          if group?
            group.set('isDeleted', false)
            group.subscribeToMessages()
            # TODO: This is techincally a race condition where messages could
            # come in between downloading them all and subscribing.
            #
            # .then =>
            #   # Fetch all messages after subscribing.
            #   group.reload()

            # Go to the room.
            @transitionTo('rooms.room', group)
        else
          controller.set('userMessage', App.userMessageFromError(json))
      , (xhr) =>
        controller.set('userMessage', App.userMessageFromError(xhr))
      .fail App.rejectionHandler
