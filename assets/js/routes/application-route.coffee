App.ApplicationRoute = Ember.Route.extend

  transitionToDefault: ->
    transition = App.get('continueTransition')
    if transition?
      App.set('continueTransition', null)
      transition.retry()
    else
      @transitionTo('rooms.index')

  actions:

    joinGroup: (joinCode) ->
      api = App.get('api')
      api.joinGroup(joinCode)
      .then (json) =>
        if ! json? || json.error?
          throw new Error(App.userMessageFromError(json))
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
      , (xhr) =>
        throw new Error(App.userMessageFromError(xhr))
      .fail App.rejectionHandler

    didLogIn: ->
      @transitionToDefault()

    didSignUp: ->
      @transitionToDefault()

    requestNotificationPermission: ->
      App.requestNotificationPermission()

    goToRoom: (room) ->
      @transitionTo('rooms.room', room)

    logOut: ->
      @transitionTo('logout')

    error: (reason) ->
      Ember.Logger.error(reason)
      return undefined

    ignore: -> # Ignore.  This is useful to cancel bubbling of actions.
