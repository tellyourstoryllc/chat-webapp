App.ApplicationRoute = Ember.Route.extend

  renderTemplate: (controller, model) ->
    obj = App.get('blowUpWithMessage')
    if obj?
      # There's some kind of fatal error.
      controller.setProperties
        userErrorTitle: obj.title
        userErrorMessage: obj.message
        userShouldRetry: obj.shouldRetry
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
      # If we were given a Group, extract its code.
      if joinCode instanceof App.Group
        joinCode = joinCode.get('joinCode') ? joinCode.get('id')

      App.get('api').joinGroup(joinCode).then (group) =>
        # Go to the room.
        @transitionTo('rooms.room', group)

    didLogIn: ->
      room = App.get('autoJoinAfterLoggingIn')
      if room?
        App.set('autoJoinAfterLoggingIn', null)
        @send('joinGroup', room)
      else
        @transitionToDefault()

    didSignUp: ->
      @transitionToDefault()

    requestNotificationPermission: ->
      App.requestNotificationPermission()

    goToRoom: (room) ->
      @transitionTo('rooms.room', room)

    didDismissMobileInstallDialog: ->
      # Destroy whatever was rendered to the modal outlet.
      @disconnectOutlet
        outlet: 'modal'
        parentView: 'application'
      return undefined

    logOut: ->
      @transitionTo('logout')

    reloadPage: ->
      window.location.reload(true)
      return undefined

    error: (reason) ->
      Ember.Logger.error(reason)
      return undefined

    ignore: -> # Ignore.  This is useful to cancel bubbling of actions.
