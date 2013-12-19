App.ApplicationRoute = Ember.Route.extend

  renderTemplate: (controller, model) ->
    obj = App.get('blowUpWithMessage')
    if obj?
      # There's some kind of fatal error.
      controller.setProperties
        userErrorTitle: obj.title
        userErrorMessage: obj.message
      @render 'error'
    else
      @_super(arguments...)

  transitionToDefault: ->
    if (transition = App.get('continueTransition'))?
      App.set('continueTransition', null)
      transition.retry()
    else if (transitionArgs = App.get('continueTransitionArgs'))?
      App.set('continueTransitionArgs', null)
      @transitionTo.apply(@, transitionArgs)
    else
      @transitionTo('rooms.index')

  actions:

    goToSignUp: ->
      @transitionTo('signup')
      return undefined

    joinGroup: (joinCode) ->
      App.get('api').joinGroup(joinCode).then (group) =>
        # Go to the room.
        @transitionTo('rooms.room', group)

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
