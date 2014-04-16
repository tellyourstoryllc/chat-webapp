App.RoomsRoomRoute = Ember.Route.extend

  deactivate: ->
    @_super(arguments...)

    App.set('currentlyViewingRoom', null)

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

  afterModel: (model, transition) ->
    if App.get('isLoggingIn')
      App.set('continueTransition', transition)
      @replaceWith('login')
    return undefined

  setupController: (controller, model) ->
    [modelId, model] = @_tryModelFromGivenContext(model)

    isOneToOne = @_typeFromRoomId(modelId) == App.OneToOne
    if ! model? && modelId? && isOneToOne
      model = App.OneToOne.lookupOrCreate(modelId)

    @_super(arguments...)

    if ! App.isLoggedIn()
      # Track in MixPanel.
      promise = App.get('api').logEvent(event_name: 'clicked_invite_link')

      # If we're not showing message content, redirect after tracking.
      if ! AppConfig.showMessages
        promise.finally =>
          url = App.Util.currentPlatformInstallAppUrl()
          if url?
            App.Util.redirect(url)
          else
            @replaceWith('index')

    # Track which room is being viewed so we can determine when to notify the
    # user.
    App.set('currentlyViewingRoom', model)

    if model?
      # Make sure we render the messages.
      model.ensureContentIsRendered()
      # Mark the room as read.
      model.set('isUnread', false)
      # Set the room as opened to show it in the list.
      model.set('isOpen', true)
      # Load preferences.
      model.scheduleLoadUserGroupPreferences?()

    if ! model?.get('associationsLoaded')
      type = if isOneToOne
        App.OneToOne
      else
        App.Group
      type.fetchAndLoadSingle(modelId)
      .then (room) =>
        # If we landed on this route, this is the first time we have the full
        # Group or OneToOne instance, so set it on the controller.
        if ! model?
          controller.set('model', room)
          App.set('currentlyViewingRoom', room)
          room.ensureContentIsRendered()
          # Load preferences.
          room.scheduleLoadUserGroupPreferences?()

        # It's possible that this isn't included in /conversations so need to
        # make sure that we're subscribed and have all messages.
        room.subscribeToMessages().then =>
          room.reload()
      , (xhrOrError) =>
        if xhrOrError?.status == 404
          # Room not found.
          # TODO: some kind of flash alert message.
          if App.isLoggedIn()
            @transitionTo('rooms.index')
          else
            @transitionTo('index')
        else
          throw xhrOrError
      .catch App.rejectionHandler

  renderTemplate: (controller, model) ->
    if App.isLoggedIn()
      # If we're logged in, business as usual.
      @_super(arguments...)
    else if AppConfig.showMessages
      @render 'view-conversation',
        controller: 'roomsViewConversation',
        into: 'application',
    else
      # If we're not logged in and not showing the message, we're redirecting.
      @render 'redirecting',
        into: 'application'

  # From the given context that we transitioned here with, extract the model ID
  # and/or model without fetching anything.
  _tryModelFromGivenContext: (model) ->
    if Ember.typeOf(model) == 'string'
      modelId = model
      model = @_typeFromRoomId(modelId).lookup(modelId)
    else if model instanceof App.User
      modelId = App.OneToOne.idFromUser(model)
      model = null
    else
      modelId = model.get('id')

    [modelId, model]

  _typeFromRoomId: (id) ->
    if /-/.test(id)
      App.OneToOne
    else
      App.Group
