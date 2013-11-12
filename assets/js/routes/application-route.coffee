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

    goToRoom: (group) ->
      @transitionTo('rooms.room', group)

    logOut: ->
      @transitionTo('logout')

    error: (reason) ->
      Ember.Logger.error(reason)
      return undefined
