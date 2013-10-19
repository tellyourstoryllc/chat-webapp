App.ApplicationRoute = Ember.Route.extend

  actions:

    requestNotificationPermission: ->
      App.requestNotificationPermission()

    goToRoom: (group) ->
      @transitionTo('rooms.room', group)

    logOut: ->
      @transitionTo('logout')
