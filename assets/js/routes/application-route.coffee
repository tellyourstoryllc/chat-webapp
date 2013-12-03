App.ApplicationRoute = Ember.Route.extend

  transitionToDefault: ->
    transition = App.get('continueTransition')
    if transition?
      App.set('continueTransition', null)
      transition.retry()
    else if (joinCode = App.get('continueJoinCode'))?
      App.set('continueJoinCode', null)
      @transitionTo('join', joinCode)
    else
      @transitionTo('rooms.index')

  actions:

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
