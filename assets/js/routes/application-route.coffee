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
    transition = App.get('continueTransition')
    if transition?
      App.set('continueTransition', null)
      transition.retry()
    else
      @transitionTo('rooms.index')

  actions:

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
