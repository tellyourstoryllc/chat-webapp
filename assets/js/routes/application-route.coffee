App.ApplicationRoute = Ember.Route.extend

  actions:

    didSignUp: ->
      transition = App.get('continueTransition')
      if transition?
        App.set('continueTransition', null)
        transition.retry()
      else
        @transitionTo('rooms.index')

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
