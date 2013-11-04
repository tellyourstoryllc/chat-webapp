#= require base-model

App.Group = App.BaseModel.extend App.LockableApiModelMixin,

  # New message draft temporarily stored before sending.
  newMessageText: ''

  # New message file temporarily stored before sending.
  newMessageFile: null

  # True when the room is visible in the list of rooms.
  isOpen: true

  isUnread: false

  # Boolean set to false when the beginning of the messages is reached.
  canLoadEarlierMessages: true
  isLoadingEarlierMessages: false

  messagesPageSize: 100

  usersLoaded: false

  # Faye subscription to listen for updates.
  subscription: null

  # Message processor extensions.  For example, encryption is implemented as a
  # processor.  Processors are called in order, with first being on the network
  # side and last being on the user-facing side.  I.e. it's like a stack and the
  # order is reversed depending on which way the message is going.
  processors: null

  # Used to expire cache of members association.
  _membersAssociationLoaded: 0

  init: ->
    @_super(arguments...)

    processors = []

    # Load the key.
    id = @get('id')
    symmetricKey = App.loadConfig('symmetricKey', if id? then "Group:#{id}")
    # If we have a key, use the encryption processor.
    if symmetricKey?
      processors.pushObject App.AesEncryptionProcessor.create(key: symmetricKey)

    @setProperties
      messages: []
      memberIds: []
      notificationResults: []
      processors: processors

  members: (->
    @get('memberIds').map((id) -> App.User.lookup(id)).compact()
  ).property('memberIds.@each', '_membersAssociationLoaded')

  # Room members sorted by status and name.
  arrangedMembers: (->
    sorted = @get('members').map (u, i) ->
      # Map to criteria so that it's only generated once.  Use index so that
      # it's stable.
      user: u
      criteria: [u.get('sortableComputedStatus'), (u.get('name') ? '').trim(), i]
    # Sort with `Ember.compare` which uses `String::localeCompare` under the
    # hood.
    .sort (a, b) -> Ember.compare(a.criteria, b.criteria)

    _.pluck sorted, 'user'
  ).property('members.@each.name', 'members.@each.sortableComputedStatus')

  isCurrentUserAdmin: (->
    @get('adminIds').contains(App.get('currentUser.id'))
  ).property('App.currentUser.id', 'adminIds.@each')

  # You should call this after all the User instances have been loaded for the
  # group.
  didLoadMembers: ->
    @set('usersLoaded', true)
    @incrementProperty('_membersAssociationLoaded')

  isNameLocked: (->
    @isPropertyLocked('name')
  ).property('_lockedProperties.@each')

  isOpenChanged: (->
    if @get('isOpen')
      @open()
    else
      @close()
  ).observes('isOpen')

  open: ->
    @subscribeToMessages()
    @fetchAndLoadAssociations()

  close: ->
    @cancelMessagesSubscription()
    @setProperties
      newMessageText: ''
      newMessageFile: null
      usersLoaded: false
      messages: []
      canLoadEarlierMessages: true

  fetchAndLoadAssociations: ->
    loadPromise = @get('loadPromise')
    # If we're already loading, just return the same promise.
    return loadPromise if loadPromise?

    promise = new Ember.RSVP.Promise (resolve, reject) =>
      if @get('usersLoaded')
        resolve(null)
      else
        @set('isLoading', true)
        App.Group.fetchById(@get('id'))
        .then (json) =>
          @setProperties(isLoading: false, loadPromise: null)

          if ! json? || json.error?
            reject(json)
            return

          # Load everything from the response.
          loadMetas = App.loadAllWithMetaData(json)
          instances = App.allInstancesFromLoadMetaData(loadMetas)

          group = instances.find (o) -> o instanceof App.Group
          group.didLoadMembers()
          if Ember.isEmpty(group.get('messages'))
            newMessages = App.newInstancesFromLoadMetaData loadMetas, (o) ->
              o instanceof App.Message
            group.set('messages', newMessages)

          resolve(loadMetas)
        , (e) =>
          @setProperties(isLoading: false, loadPromise: null)
          reject(e)

    # Store the promise so that others can attach to it.
    @set('loadPromise', promise)

    promise

  isFayeClientConnectedChanged: (->
    if ! @get('subscription')?
      # If we're not listening, we don't care.
      return

    if App.get('isFayeClientConnected')
      @didReconnect()
  ).observes('App.isFayeClientConnected')

  didReconnect: ->
    # We just reconnected.  Fetch any messages we may have missed.
    @fetchMostRecentMessages()
    .then (loadMetas) =>
      overlapFound = loadMetas.any ([inst, isNew]) ->
        # Consider there to be overlap if any of the most recent messages were
        # already in our store.
        isNew? && ! isNew && inst instanceof App.Message

      newMessages = App.newInstancesFromLoadMetaData loadMetas, (o) ->
        o instanceof App.Message
      if overlapFound
        # After fetching the most recent page of messages, we found that we
        # already had one or more of them.  Notify the user of each message like
        # normal.
        @didReceiveMessage(msg) for msg in newMessages
      else
        # No overlap.  This means that we missed more than a page of messages
        # when disconnected.  Just give up and reload.  Don't notify the user.
        @get('messages').clear()
        for msg in newMessages
          @didReceiveMessage(msg, suppressNotifications: true)

  # Fetch most recent messages, load them, and resolve returned promise to all
  # instances.
  fetchMostRecentMessages: ->
    api = App.get('api')
    data =
      limit: @get('messagesPageSize')
    api.ajax(api.buildURL("/groups/#{@get('id')}/messages"), 'GET', data: data)
    .then (json) =>
      if ! json? || json.error?
        throw json
      else
        json = Ember.makeArray(json)
        # Load everything from the response.
        return App.loadAllWithMetaData(json)

  cancelMessagesSubscription: ->
    @get('subscription')?.cancel()
    @set('subscription', null)

  subscribeToMessages: ->
    # If we already have a subscription, we're done.
    return if @get('subscription')?

    client = App.get('fayeClient')
    groupId = @get('id')
    if ! groupId?
      Ember.Logger.warn "I can't subscribe to messages without a group ID."
      return

    subscription = client.subscribe "/groups/#{groupId}/messages", (json) =>
      Ember.run @, ->
        Ember.Logger.log "received packet", json
        if ! json?.error? && json.object_type == 'message'
          # We received a new message.
          [message, isNew] = App.Message.loadRawWithMetaData(json)
          # If it's a Message we've created before, just ignore it.  Otherwise,
          # trigger our callback.
          @didReceiveMessage(message) if isNew
    @set('subscription', subscription)

  didReceiveMessage: (message, options = {}) ->
    # Make sure the sender is loaded before displaying it.
    message.fetchAndLoadAssociations()
    .then (result) =>
      # Add the message to the room list.
      @get('messages').pushObject(message)

      return result if options.suppressNotifications

      fromCurrentUser = message.get('userId') == App.get('currentUser.id')
      wasMentioned = message.doesMentionUser(App.get('currentUser'))
      if ! fromCurrentUser && wasMentioned
        # The current user was mentioned.  Play sound.
        @playMentionSound()

      if ! fromCurrentUser &&
      (! App.get('hasFocus') || App.get('currentlyViewingRoom') != @)
        if wasMentioned
          @createDesktopNotification(message)
        else
          @playRecieveMessageSound() if App.get('preferences.playSoundOnMessageReceive')
          @createDesktopNotification(message) if App.get('preferences.showNotificationOnMessageReceive')

      if ! fromCurrentUser && App.get('currentlyViewingRoom') != @
        # Mark the room as unread.
        @set('isUnread', true)

      if ! fromCurrentUser && ! App.get('hasFocus')
        # Flash the window's titlebar.
        titleObj = Ember.Object.create
          id: message.get('groupId')
          title: message.get('title')
        App.get('pageTitlesToFlash').unshiftObject(titleObj)

      # Make sure to return what we were given for other listeners.
      return result

    true

  playMentionSound: ->
    return unless Modernizr.audio
    audio = $('.mention-sound').get(0)
    audio.currentTime = 0 if audio.currentTime > 0
    audio.play()

  playRecieveMessageSound: ->
    return unless Modernizr.audio
    audio = $('.receive-message-sound').get(0)
    audio.currentTime = 0 if audio.currentTime > 0
    audio.play()

  # Create (or update) the desktop notification.
  createDesktopNotification: (message) ->
    # Create a desktop notification.
    notif = message.toNotification()
    title = notif.title
    delete notif.title
    result = window.notify.createNotification(title, notif)
    @get('notificationResults').pushObject(result)
    if result.nativeNotification?.addEventListener
      result.nativeNotification.addEventListener 'click', (event) ->
        # The user clicked the notification.  Focus the window and go to the
        # room.
        $(window).focus()
        applicationController = App.__container__.lookup('controller:application')
        applicationController.send('goToRoom', message.get('group'))

      result.nativeNotification.addEventListener 'close', (event) ->
        # The user closed the notification.  Stop flashing that message.
        titleObjs = App.get('pageTitlesToFlash')
        groupId = message.get('groupId')
        objs = titleObjs.filterBy('id', groupId)
        titleObjs.removeObjects(objs)

  messageIds: Ember.computed.mapBy('messages', 'id')

  # The min message ID stored as a number.
  minNumericMessageId: Ember.reduceComputed.call null, 'messageIds',
    initialValue: Infinity
    addedItem: (accumulatedValue, item, changeMeta, instanceMeta) ->
      Math.min(accumulatedValue, parseInt(item))
    removedItem: (accumulatedValue, item, changeMeta, instanceMeta) ->
      return accumulatedValue if parseInt(item) > accumulatedValue
      return undefined

  fetchAndLoadEarlierMessages: ->
    return unless @get('usersLoaded') && @get('canLoadEarlierMessages')
    return if @get('isLoadingEarlierMessages')

    api = App.get('api')
    groupId = @get('id')
    data =
      limit: @get('messagesPageSize')
    minMessageId = @get('minNumericMessageId')
    data.last_message_id = minMessageId if minMessageId < Infinity

    @set('isLoadingEarlierMessages', true)
    api.ajax(api.buildURL("/groups/#{groupId}/messages"), 'GET', data: data)
    .then (json) =>
      @set('isLoadingEarlierMessages', false)

      if ! json? || json.error?
        throw json

      loadMetas = App.loadAllWithMetaData(Ember.makeArray(json))
      if Ember.isEmpty(loadMetas)
        # We've reached the beginning.
        @set('canLoadEarlierMessages', false)
      messages = App.newInstancesFromLoadMetaData loadMetas, (o) ->
        o instanceof App.Message
      @get('messages').unshiftObjects(messages)

      return messages
    , (e) =>
      @set('isLoadingEarlierMessages', false)
      throw e

  processIncomingMessageText: (message, text) ->
    newText = text
    for processor in @get('processors')
      if Ember.typeOf(processor) == 'instance'
        target = processor.get('target')
        method = processor.get('incoming')
      else
        target = processor.target
        method = processor.incoming
      target ?= processor
      method = target[method] if Ember.typeOf(method) == 'string'
      if method?
        newText = method.call(target, message, newText)

    newText

  processOutgoingMessageText: (message, text) ->
    newText = text
    for processor in @get('processors') by -1
      if Ember.typeOf(processor) == 'instance'
        target = processor.get('target')
        method = processor.get('outgoing')
      else
        target = processor.target
        method = processor.outgoing
      target ?= processor
      method = target[method] if Ember.typeOf(method) == 'string'
      if method?
        newText = method.call(target, message, newText)

    newText


App.Group.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  _allActive: null

  propertiesFromRawAttrs: (json) ->
    id: App.BaseModel.coerceId(json.id)
    name: json.name
    joinUrl: json.join_url
    topic: json.topic
    adminIds: (json.admin_ids ? []).map (id) -> App.BaseModel.coerceId(id)
    memberIds: (json.member_ids ? []).map (id) -> App.BaseModel.coerceId(id)

  # Given json for a Group and all its associations, load it, and return the
  # `App.Group` instance.
  loadSingleGroup: (json) ->
    instances = App.loadAll(json)
    group = instances.find (o) -> o instanceof App.Group
    group.didLoadMembers()
    if Ember.isEmpty(group.get('messages'))
      group.set('messages', instances.filter (o) -> o instanceof App.Message)

  fetchAll: ->
    api = App.get('api')
    api.ajax(api.buildURL('/groups'), 'GET', data: {})
    .then (json) =>
      if ! json?.error?
        json = Ember.makeArray(json)
        groupObjs = json.filter (o) -> o.object_type == 'group'
        groups = groupObjs.map (g) -> App.Group.loadRaw(g)
        return groups
      else
        throw new Error(json)

  fetchById: (id) ->
    api = App.get('api')
    data =
      limit: 100
    api.ajax(api.buildURL("/groups/#{id}"), 'GET', data: data)

  createRecord: (data) ->
    api = App.get('api')
    api.ajax(api.buildURL('/groups/create'), 'POST', data: data)
    .then (json) =>
      if json? && ! json.error?
        json = Ember.makeArray(json)
        groupAttrs = json.find (o) -> o.object_type == 'group'
        group = @loadRaw(groupAttrs)
        return group
      else
        throw json
