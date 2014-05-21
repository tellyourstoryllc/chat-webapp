App.Conversation = Ember.Mixin.create

  # Array of messages in the conversation.
  messages: null

  # Array of messages to actually display.  Anything in this collection is
  # bound to the DOM.  To prevent slow initial loading in the browser, this is
  # initially kept empty.
  displayMessages: null

  # True when we're rending this conversation's content in the DOM.
  isRenderingContent: false

  # New message draft temporarily stored before sending.
  newMessageText: ''

  # New message file temporarily stored before sending.
  newMessageFile: null

  # True when the room is visible in the list of rooms.
  isOpen: true

  isUnread: false

  isDisplayedInList: false

  # Date (timestamp) that this conversation last had activity.  Non-event
  # messages count as activity.
  lastActiveAt: null

  # Local version of `lastSeenRank`.
  localLastSeenRank: null

  # Boolean set to false when the beginning of the messages is reached.
  canLoadEarlierMessages: true
  isLoadingEarlierMessages: false

  messagesPageSize: 60

  # This should be less than or equal to the initial fetch limit.  Otherwise it
  # causes duplicates.
  messagesLimitOnReconnect: 40

  usersLoaded: false

  loadPromise: null

  # Date when this instance handled a reconnect.
  reconnectedAt: null

  # Message processor extensions.  For example, encryption is implemented as a
  # processor.  Processors are called in order, with first being on the network
  # side and last being on the user-facing side.  I.e. it's like a stack and the
  # order is reversed depending on which way the message is going.
  processors: null

  # Used to expire cache of members association.
  _membersAssociationLoaded: 0

  # Flag to communicate to the view that we need to ignore the current scroll
  # state and scroll the room to the last message.
  forceScroll: false

  isSubscribedToUpdates: Ember.required(Function)

  fetchUrl: Ember.required(Function)

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

    App.get('eventTarget').on 'didConnect', @, @didConnect

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

  # This is needed for when not displaying status.
  alphabeticMembers: (->
    App.RecordArray.create(content: @get('members'), sortProperties: ['name'])
  ).property('members')

  arrangedByIdMembers: (->
    App.RecordArray.create(content: @get('members'), sortProperties: ['id'])
  ).property('members')

  isCurrentUserMember: (->
    @get('memberIds').contains(App.get('currentUser.id'))
  ).property('App.currentUser.id', 'memberIds.@each')

  isUserAnAdmin: (user) ->
    (@get('admins') ? []).contains(user)

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
    @subscribeAndLoad(reload: false)

  didClose: ->

  subscribeAndLoad: (options = {}) ->
    _.defaults options, { reload: true }

    @subscribeToMessages().then =>
      # To prevent race condition where messages get dropped between initial
      # load and subscribe, we need to reload after subscribing to fetch those
      # messages.
      @reload() if options.reload

    @fetchAndLoadAssociations()

  # Calling this ensures that all messages and user wallpaper are rendered in
  # the DOM.
  ensureContentIsRendered: ->
    @set('displayMessages', @get('messages'))
    @set('isRenderingContent', true)
    undefined

  ensureDisplayableInList: ->
    @subscribeToMessages().then =>
      # To prevent race condition where messages get dropped between initial
      # load and subscribe, we need to reload after subscribing to fetch those
      # messages.
      @reload()
    undefined

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

          convo = instances.find (o) => o instanceof @constructor
          convo.didLoadMembers()
          if Ember.isEmpty(convo.get('messages'))
            newMessages = App.newInstancesFromLoadMetaData loadMetas, (o) ->
              o instanceof App.Message
            convo.get('messages').addObjects(newMessages)

          resolve(loadMetas)
        , (e) =>
          @setProperties(isLoading: false, loadPromise: null)
          reject(e)

    # Store the promise so that others can attach to it.
    @set('loadPromise', promise)

    promise

  didConnect: ->
    if ! @get('associationsLoaded') || ! @get('isSubscribedToUpdates')
      # If we're not loaded or not listening, we don't care.
      return

    if App.get('isFayeClientConnected')
      @didReconnect()

  didReconnect: ->
    @set('reconnectedAt', new Date())
    # We just reconnected.  Fetch any messages we may have missed.
    @fetchConversationWithMostRecentMessages()
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
        @didReceiveMessage(msg, insertInRankOrder: true) for msg in newMessages
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

  # Fetch the conversation (with users and most recent messages), load them, and
  # resolve returned promise to all instances.
  fetchConversationWithMostRecentMessages: ->
    api = App.get('api')
    data =
      limit: @get('messagesLimitOnReconnect')
    api.ajax(@fetchUrl(), 'GET', data: data)
    .then (json) =>
      if ! json? || json.error?
        throw json
      # Load everything from the response.
      return App.loadAllWithMetaData(json)
    .catch App.rejectionHandler

  # Handler for when we receive an object over the socket for this conversation.
  #
  # options.forceNotify if true, treats message as a new message, even if it's
  #                     been loaded already.
  didReceiveUpdateFromFaye: (json, options = {}) ->
    Ember.Logger.log "received packet", json if App.get('useDebugLogging')
    if ! json? || json.error?
      return

    if json.object_type == 'message'
      # We received a message over the socket.
      [message, isNew] = App.Message.loadRawWithMetaData(json)
      # If it's a message we've never instantiated before, trigger our callback
      # like usual. Otherwise, just ignore it.
      if isNew
        @didReceiveMessage(message)
      else if options.forceNotify
        # In certain cases, we may need to treat it as a new message in the UI,
        # such as the very first message of a OneToOne we've never seen before,
        # even if the message has been instantiated before (from loading the
        # OneToOne).
        @notifyInUiOfMessage(message)

    if json.object_type in ['group', 'one_to_one']
      # We received an update to the conversation.
      type = App.classFromRawObject(json)
      convo = type.lookup(json.id)
      oldMemberIds = convo.get('memberIds').copy()
      oldLastSeenRank = convo.get('lastSeenRank')

      # Load the new data.
      @constructor.loadRawWithMetaData(json)

      # Find users that joined or left the group.
      newMemberIds = convo.get('memberIds')
      oldMemberIds.forEach (oldId) =>
        if ! newMemberIds.contains(oldId)
          user = App.User.lookup(oldId)
          @userDidLeave(user) if user?
      newMemberIds.forEach (newId) =>
        if ! oldMemberIds.contains(newId)
          # The user might not be loaded yet here.  Fetch the user if necessary.
          user = App.User.lookup(newId)
          if user?
            @userDidJoin(user)
          else
            App.User.fetchAndLoadSingle(newId).then (user) =>
              # Invalidate the cache of members.
              @incrementProperty('_membersAssociationLoaded')
              @userDidJoin(user)

      # Mark any unseen conversations as seen if they were seen on another
      # client.
      newLastSeenRank = convo.get('lastSeenRank')
      if newLastSeenRank? && (! oldLastSeenRank? || newLastSeenRank > oldLastSeenRank)
        lastMessageRank = @lastMessageRank()
        if lastMessageRank? && lastMessageRank <= newLastSeenRank
          @set('isUnread', false)

  userDidJoin: (user) ->
    if user == App.get('currentUser')
      # If the current user is joining a room, and it was left before, re-enter.
      @setProperties
        isOpen: true
        isDeleted: false
      # Always subscribe.
      @subscribeAndLoad()

    if App.get('preferences.clientWeb.showJoinLeaveMessages')
      message = App.SystemMessage.createFromConversation(@, localText: "#{user.get('name')} joined.")
      @didReceiveMessage(message, suppressNotifications: true)

  userDidLeave: (user) ->
    if App.get('preferences.clientWeb.showJoinLeaveMessages')
      message = App.SystemMessage.createFromConversation(@, localText: "#{user.get('name')} left for good.")
      @didReceiveMessage(message, suppressNotifications: true)

    if user == App.get('currentUser')
      # Current user left the room, possibly in another client.
      @set('isDeleted', true)
      # Stop listening for messages.
      @set('isOpen', false)

  didReceiveMessage: (message, options = {}) ->
    # Make sure the sender is loaded before displaying it.
    message.fetchAndLoadAssociations()
    .then (result) =>
      # Add the message to the room list.
      if options.insertInRankOrder
        @insertMessageInRankOrder(message)
      else
        @get('messages').pushObject(message)

      @set('forceScroll', true) if options.forceScroll

      # Mark this conversation as active, if this isn't a system message.
      if ! message.get('isSystemMessage')
        newActiveAt = message.get('createdAt') ? new Date()
        # Active at should only ever get newer, not older.
        previousActiveAt = @get('lastActiveAt')
        if ! previousActiveAt? || previousActiveAt.getTime() < newActiveAt.getTime()
          @set('lastActiveAt', newActiveAt)

      # Determine if this message has already been seen on another client.
      userSawOnAnotherClient = @hasMessageBeenSeen(message)

      @notifyInUiOfMessage(message) if ! options.suppressNotifications && ! userSawOnAnotherClient

      # Make sure to return what we were given for other listeners.
      return result

    true

  hasLoadedMessagesFromServer: ->
    messages = @get('messages')
    return false unless messages?

    msgWithId = messages.find (m) => m.get('id')?

    msgWithId?

  # Insert a message instance into the messages list based on rank.  Returns the
  # index it was inserted at.  This is linear O(n) in worst case since messages
  # aren't necessarily already in rank order.  But normally we have new messages
  # that we're appending to the end after a reconnect.  So usually this
  # shouldn't be bad.
  insertMessageInRankOrder: (message) ->
    messages = @get('messages')
    messageRank = message.get('rank')
    if ! messageRank?
      # If for some reason the message doesn't have a rank of its own, just
      # append it.
      messages.pushObject(message)
      return messages.get('length') - 1

    foundIndex = null
    for i in [messages.get('length') - 1 .. 0] by -1
      curMsg = messages.objectAt(i)
      curRank = curMsg?.get('rank')
      # If this message has no rank, it's probably because the current user sent
      # it and we're still waiting for a response.  Or it's a system message
      # that we inserted and probably want to keep it near the bottom.
      continue if ! curRank?

      if curRank < messageRank
        messages.insertAt(i + 1, message)
        foundIndex = i + 1
        break

    if ! foundIndex?
      # Couldn't find a spot; just append.
      messages.pushObject(message)
      foundIndex = messages.get('length') - 1

    foundIndex

  # This is linear in the number of messages in the worst case, but usually the
  # very first message checked is our answer.
  lastMessageRank: ->
    messages = @get('messages')
    len = messages.get('length')
    # System messages may not have a rank, so need to look for one.
    for i in [len - 1 .. 0] by -1
      rank = messages.objectAt(i).get('rank')
      return rank if rank?
    null

  hasMessageBeenSeen: (message) ->
    messageRank = message.get('rank')
    lastSeenRank = @get('localLastSeenRank')
    lastSeenRank ?= @get('lastSeenRank')

    messageRank? && lastSeenRank? && messageRank <= lastSeenRank

  isUserActivelyViewing: ->
    App.get('currentlyViewingRoom') == @ && App.get('hasFocus') &&
    ! App.get('isIdle') && App.get('idleForSeconds') < 60

  markLastMessageAsSeen: ->
    # Update local last seen message rank.
    messageRank = @lastMessageRank()
    localLastSeenRank = @get('localLastSeenRank')
    if messageRank? && (! localLastSeenRank? || messageRank > localLastSeenRank)
      @set('localLastSeenRank', messageRank)
      # The local rank changed.  Push the update to the API.
      @updateLastSeenRank()
    undefined

  _updateLastSeenRank: ->
    localLastSeenRank = @get('localLastSeenRank')
    lastSeenRank = @get('lastSeenRank')
    if localLastSeenRank? && (! lastSeenRank? || localLastSeenRank > lastSeenRank)
      # Our local rank is more recent than our best known remote rank, so really
      # send it to the API.
      App.get('api').updateLastSeenRank(@, localLastSeenRank)

  updateLastSeenRank: _.throttle ->
    @_updateLastSeenRank()
  , 1000, leading: false

  notifyInUiOfMessage: (message) ->
    fromCurrentUser = message.get('userId') == App.get('currentUser.id')
    wasMentioned = message.doesMentionUser(App.get('currentUser'))
    hasFocus = App.get('hasFocus')
    isOneToOne = message.get('oneToOneId')?
    if ! fromCurrentUser && wasMentioned
      # The current user was mentioned.  Play sound.
      @playMentionSound() if App.get('preferences.clientWeb.playSoundOnMention')

    if ! fromCurrentUser &&
    (! hasFocus || App.get('currentlyViewingRoom') != @ || App.get('isIdle'))
      if wasMentioned
        @createDesktopNotification(message) if App.get('preferences.clientWeb.showNotificationOnMention')
      else if isOneToOne
        @playReceiveMessageSound() if App.get('preferences.clientWeb.playSoundOnOneToOneMessageReceive')
        @createDesktopNotification(message) if App.get('preferences.clientWeb.showNotificationOnOneToOneMessageReceive')
      else
        @playReceiveMessageSound() if App.get('preferences.clientWeb.playSoundOnMessageReceive')
        @createDesktopNotification(message) if App.get('preferences.clientWeb.showNotificationOnMessageReceive')

    if ! fromCurrentUser &&
      (App.get('currentlyViewingRoom') != @ || App.PageVisibility.hidden() ||
        # This case is for when an older browser is put in a background tab.
        ! hasFocus && ! App.PageVisibility.isSupported)
      # Mark the room as unread.
      @set('isUnread', true)

    if ! fromCurrentUser && ! hasFocus
      # Bounce the dock icon.
      if wasMentioned && App.get('preferences.clientWeb.bounceDockOnMention') ||
      isOneToOne && App.get('preferences.clientWeb.bounceDockOnOneToOneMessageReceive') ||
      ! wasMentioned && ! isOneToOne && App.get('preferences.clientWeb.bounceDockOnMessageReceive')
        macgap?.app.bounce()

    undefined

  playMentionSound: ->
    return unless Modernizr.audio
    audio = $('.mention-sound').get(0)
    audio.currentTime = 0 if audio.currentTime > 0
    audio.play()

  playReceiveMessageSound: ->
    return unless Modernizr.audio
    audio = $('.receive-message-sound').get(0)
    audio.currentTime = 0 if audio.currentTime > 0
    audio.play()

  # Create (or update) the desktop notification.
  createDesktopNotification: (message) ->
    # Create a desktop notification.
    notif = message.toNotification()

    # Create a desktop notification for the native app.
    macgap?.skymob?.notify?(_.clone(notif))

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
        applicationController.send('goToRoom', message.get('conversation'))

      result.nativeNotification.addEventListener 'close', (event) ->
        # The user closed the notification.

  dismissNotifications: ->
    results = @get('notificationResults')
    if results?
      results.forEach (result) -> result.close()
      results.clear()

  messageRanks: Ember.computed.mapBy('messages', 'rank')

  # The min message rank.
  minMessageRank: Ember.reduceComputed.call null, 'messageRanks',
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
    minMessageRank = @get('minMessageRank')

    # Don't do anything if we don't already have a message to query from.  If we
    # don't, it means the conversation isn't loaded yet.
    return unless minMessageRank? && minMessageRank < Infinity

    api = App.get('api')
    groupId = @get('id')
    data =
      limit: @get('messagesPageSize')
      below_rank: minMessageRank

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
    .catch App.rejectionHandler

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
        try
          # Run the processor.
          newText = method.call(target, message, newText)
        catch e
          # If it fails, just show the original message to the user.
          Ember.Logger.error "Error running incoming message processor; skipping", e, e?.message, e?.stack ? e?.stacktrace

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
        # TODO: what should happen if this fails?
        newText = method.call(target, message, newText)

    newText
