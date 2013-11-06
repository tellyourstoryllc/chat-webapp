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

    goToOneToOne: (userOrOneToOne) ->
      Ember.Logger.log "Going to OneToOne"
      if userOrOneToOne instanceof App.User
        return if userOrOneToOne == App.get('currentUser')
        id = App.OneToOne.idFromUserIds(userOrOneToOne.get('id'), App.get('currentUser.id'))
      else if userOrOneToOne instanceof App.OneToOne
        oneToOne = userOrOneToOne
      else if Ember.typeOf(userOrOneToOne) == 'string'
        id = userOrOneToOne
      if id?
        oneToOne = App.OneToOne.lookupOrCreate(id)
        @transitionTo('rooms.room', oneToOne)
        oneToOne.reload()

      return undefined

    logOut: ->
      @transitionTo('logout')
