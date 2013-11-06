App.RoomsRoomRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)

    App.set('currentlyViewingRoom', null)

  beforeModel: (transition) ->
    if ! App.isLoggedIn()
      App.set('continueTransition', transition)
      @transitionTo('login')
      return

  serialize: (model) ->
    id = if Ember.typeOf(model) == 'string'
      model
    else if model instanceof App.User
      App.OneToOne.idFromUserIds(model.get('id'), App.get('currentUser.id'))
    else
      model.get('id')

    room_id: id

  model: (params, transition) ->
    params.room_id

  setupController: (controller, model) ->
    if Ember.typeOf(model) == 'string'
      modelId = model
      model = @_typeFromRoomId(modelId).lookup(modelId)
    else if model instanceof App.User
      modelId = App.OneToOne.idFromUser(model)
      model = null
    else
      modelId = model.get('id')

    isOneToOne = @_typeFromRoomId(modelId) == App.OneToOne
    if ! model? && modelId? && isOneToOne
      model = App.OneToOne.lookupOrCreate(modelId)

    @_super(arguments...)

    # Track which room is being viewed so we can determine when to notify the
    # user.
    App.set('currentlyViewingRoom', model)

    if model?
      # Mark the room as read.
      model.set('isUnread', false)
      # Set the room as opened to show it in the list.
      model.set('isOpen', true)

    if ! model?.get('usersLoaded')
      if isOneToOne
        App.OneToOne.fetchAndLoadSingle(modelId)
        .then (oneToOne) =>
          controller.set('model', oneToOne)
          App.set('currentlyViewingRoom', oneToOne)
      else
        App.Group.fetchById(modelId)
        .then (json) =>
          if ! json.error?
            # Load everything from the response.
            group = App.Group.loadSingleGroup(json)

            # If we landed on this route, this is the first time we have the full
            # Group instance, so set it on the controller.
            if ! model?
              model = group
              controller.set('model', model)
              App.set('currentlyViewingRoom', model)

  _typeFromRoomId: (id) ->
    if /-/.test(id)
      App.OneToOne
    else
      App.Group
