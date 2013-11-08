App.Conversation = Ember.Mixin.create

  # Array of messages in the conversation.
  messages: null

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

  loadPromise: null

  # Message processor extensions.  For example, encryption is implemented as a
  # processor.  Processors are called in order, with first being on the network
  # side and last being on the user-facing side.  I.e. it's like a stack and the
  # order is reversed depending on which way the message is going.
  processors: null

  # Used to expire cache of members association.
  _membersAssociationLoaded: 0

  isListeningForMessages: Ember.required(Function)

  mostRecentMessagesUrl: Ember.required(Function)

  earlierMessagesUrl: Ember.required(Function)

  publishMessageWithAttachmentUrl: Ember.required(Function)

  publishMessageChannelName: Ember.required(Function)

  init: ->
    @_super(arguments...)

    processors = []

    # Load the key.
    id = @get('id')
    symmetricKey = App.loadConfig('symmetricKey', if id? then "#{@constructor}:#{id}")
    # If we have a key, use the encryption processor.
    if symmetricKey?
      processors.pushObject App.AesEncryptionProcessor.create(key: symmetricKey)

    props =
      processors: processors

    # Initialize empty array properties, but only if they're not already set.
    for name in ['messages', 'memberIds', 'notificationResults']
      val = @get(name)
      if ! val?
        props[name] = []

    @setProperties(props)

  # Marks a class as a conversation.
  actsLikeConversation: true

  associationsLoaded: Ember.computed.alias('usersLoaded')

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

  # You should call this after all the User instances have been loaded for the
  # group.
  didLoadMembers: ->
    @set('usersLoaded', true)
    @incrementProperty('_membersAssociationLoaded')

  isEncrypted: (->
    @get('processors').any (p) -> p instanceof App.AesEncryptionProcessor
  ).property('processors.@each')

  isOpenChanged: (->
    if @get('isOpen')
      @didOpen()
    else
      @didClose()
  ).observes('isOpen')

  didOpen: ->
    @subscribeToMessages()
    @fetchAndLoadAssociations()

  didClose: ->

  fetchAndLoadAssociations: ->
    loadPromise = @get('loadPromise')
    # If we're already loading, just return the same promise.
    return loadPromise if loadPromise?

    promise = new Ember.RSVP.Promise (resolve, reject) =>
      if @get('usersLoaded')
        resolve(null)
      else
        @set('isLoading', true)
        @constructor.fetchById(@get('id'))
        .then (json) =>
          @setProperties(isLoading: false, loadPromise: null)

          if ! json? || json.error?
            reject(json)
            return

          # Load everything from the response.
          loadMetas = App.loadAllWithMetaData(json)
          instances = App.allInstancesFromLoadMetaData(loadMetas)

          convo = instances.find (o) -> o instanceof @constructor
          convo.didLoadMembers()
          if Ember.isEmpty(convo.get('messages'))
            newMessages = App.newInstancesFromLoadMetaData loadMetas, (o) ->
              o instanceof App.Message
            convo.set('messages', newMessages)

          resolve(loadMetas)
        , (e) =>
          @setProperties(isLoading: false, loadPromise: null)
          reject(e)

    # Store the promise so that others can attach to it.
    @set('loadPromise', promise)

    promise

  isFayeClientConnectedChanged: (->
    if ! @get('associationsLoaded') || ! @get('isSubscribedToUpdates')
      # If we're not loaded or not listening, we don't care.
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
        # when disconnected.  Just give up and reload.  We need to clear the old
        # messages out of our store so that if the user pages back through
        # history, they're seen as new instances again.
        currentMessages = @get('messages')
        App.Message.discardRecords(currentMessages)
        currentMessages.clear()
        # Don't notify the user.
        for msg in newMessages
          @didReceiveMessage(msg, suppressNotifications: true)

  # Fetch most recent messages, load them, and resolve returned promise to all
  # instances.
  fetchMostRecentMessages: ->
    api = App.get('api')
    data =
      limit: @get('messagesPageSize')
    api.ajax(@mostRecentMessagesUrl(), 'GET', data: data)
    .then (json) =>
      if ! json? || json.error?
        throw json
      else
        json = Ember.makeArray(json)
        # Load everything from the response.
        return App.loadAllWithMetaData(json)

  didReceiveUpdateFromFaye: (json) ->
    Ember.Logger.log "received packet", json
    if ! json? || json.error?
      return

    if json.object_type == 'message'
      # We received a new message.
      [message, isNew] = App.Message.loadRawWithMetaData(json)
      # If it's a Message we've created before, just ignore it.  Otherwise,
      # trigger our callback.
      @didReceiveMessage(message) if isNew

    if json.object_type in ['group', 'one_on_one']
      # We received an update to the conversation.
      type = App.classFromRawObject(json)
      convo = type.lookup(json.id)
      oldMemberIds = convo.get('memberIds').copy()

      # Load the new data.
      @constructor.loadRawWithMetaData(json)

      # Create join and leave messages here.
      newMemberIds = convo.get('memberIds')
      oldMemberIds.forEach (oldId) =>
        if ! newMemberIds.contains(oldId)
          user = App.User.lookup(oldId)
          message = App.SystemMessage.create(localText: "#{user.get('name')} left for good.")
          @didReceiveMessage(message, suppressNotifications: true)
      newMemberIds.forEach (newId) =>
        if ! oldMemberIds.contains(newId)
          # TODO: The user might not be loaded yet here.  Fetch the user
          # before proceeding.
          user = App.User.lookup(newId)
          if user?
            message = App.SystemMessage.create(localText: "#{user.get('name')} joined.")
            @didReceiveMessage(message, suppressNotifications: true)

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
        tag = message.get('notificationTag')
        objs = titleObjs.filterBy('id', tag)
        titleObjs.removeObjects(objs)

  messageIds: Ember.computed.mapBy('messages', 'id')

  # The min message ID stored as a number.
  minNumericMessageId: Ember.reduceComputed.call null, 'messageIds',
    initialValue: Infinity
    addedItem: (accumulatedValue, item, changeMeta, instanceMeta) ->
      n = parseInt(item)
      return accumulatedValue if ! n? || _.isNaN(n)
      Math.min(accumulatedValue, n)
    removedItem: (accumulatedValue, item, changeMeta, instanceMeta) ->
      n = parseInt(item)
      return accumulatedValue if _.isNaN(n) || n > accumulatedValue
      return undefined

  fetchAndLoadEarlierMessages: ->
    return unless @get('usersLoaded') && @get('canLoadEarlierMessages')
    return if @get('isLoadingEarlierMessages')
    minMessageId = @get('minNumericMessageId')

    # Don't do anything if we don't already have a message to query from.  If we
    # don't, it means the conversation isn't loaded yet.
    return unless minMessageId? && minMessageId < Infinity

    api = App.get('api')
    groupId = @get('id')
    data =
      limit: @get('messagesPageSize')
      last_message_id: minMessageId

    @set('isLoadingEarlierMessages', true)
    api.ajax(@earlierMessagesUrl(), 'GET', data: data)
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

  # Hook that gets called with the App.Message and the payload (faye data built
  # from the message) just before it is published to the channel via socket.
  willSendMessageToChannel: Ember.K

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
