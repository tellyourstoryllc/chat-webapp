App.ApplicationRoute = Ember.Route.extend

  actions:

    requestNotificationPermission: ->
      App.requestNotificationPermission()