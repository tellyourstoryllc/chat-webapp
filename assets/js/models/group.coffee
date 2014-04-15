#= require base-model
#= require conversation

App.Group = App.BaseModel.extend App.Conversation, App.LockableApiModelMixin,

  # Join code that the user entered in before submitting.
  enteredJoinCode: ''

  # Set to true when attempting to join.
  isJoining: false

  # Faye subscription to listen for updates.
  subscription: null

  # Show the UI to set topics.
  canSetTopic: true

  # Currently, all groups are public.
  canJoinWithoutCode: true

  # Show room door icon in UI.
  isRoom: true

  defaultAvatarUrl: App.webServerUrl('imageRoom')

  avatarUrl: Ember.computed.defaultTo('defaultAvatarUrl')

  # TODO: load the actual preference.
  serverAllMessagesEmail: true
  isLoadingUserGroupPreferences: false
  isUserGroupPreferencesLoaded: false
  loadUserGroupPreferencesTimer: null

  admins: (->
    @get('adminIds').map((id) -> App.User.lookup(id)).compact()
  ).property('adminIds.@each', '_membersAssociationLoaded')

  joinCode: (->
    App.Group.parseJoinCode(@get('joinUrl'))
  ).property('joinUrl')

  isCurrentUserAdmin: (->
    @get('adminIds').contains(App.get('currentUser.id'))
  ).property('App.currentUser.id', 'adminIds.@each')

  isNameLocked: (->
    @isPropertyLocked('name')
  ).property('_lockedProperties.@each')

  isSubscribedToUpdates: (->
    @get('subscription')?
  ).property('subscription')

  isInternal: true

  # Groups default to not open since they are all internal and aren't displayed.
  # This is an optimization that prevents them from being subscribed to.
  isOpen: false

  statusText: Ember.computed.alias('topic')

  # Returns true if this room should show in the UI an invite users tip.
  needsInviteTip: ->
    return false if @get('_userJustCreatedWithMembers')

    # Show the invite tip if there are no members and no messages.  You may want
    # to create a room for yourself.  Also, only show this if you're a member.
    numMembers = @get('memberIds.length')
    noMembers = numMembers? && numMembers < 2
    noMessages = (@get('messages.length') ? 0) == 0
    isMember = @get('isCurrentUserMember')

    noMembers && noMessages && isMember

  didClose: ->
    @_super(arguments...)
    # Stop listening for updates.
    @cancelMessagesSubscription()
    # Discard messages.
    messages = @get('messages')
    App.Message.discardRecords(messages)
    messages.clear()
    # Reset other properties.
    @setProperties
      newMessageText: ''
      newMessageFile: null
      usersLoaded: false
      canLoadEarlierMessages: true

  cancelMessagesSubscription: ->
    @get('subscription')?.cancel()
    @set('subscription', null)

  subscribeToMessages: ->
    # If we already have a subscription, we're done.
    subscription = @get('subscription')
    return subscription if subscription?

    client = App.get('fayeClient')
    groupId = @get('id')
    if ! groupId?
      Ember.Logger.warn "I can't subscribe to messages without a group ID."
      return null

    # TODO: Create a wrapping promise.  If subscribing fails, retry, and don't
    # resolve the promise until subscribing succeeds.  Currently, if subscibing
    # fails, faye doesn't seem to retry, so we're hosed, i.e. the app thinks
    # we've subscribed but we haven't.

    subscription = client.subscribe "/groups/#{groupId}/messages", (json) =>
      Ember.run @, ->
        @didReceiveUpdateFromFaye(json)
    @set('subscription', subscription)

    return subscription

  topicDidChange: (->
    topic = @get('topic')
    text = if Ember.isEmpty(topic)
      "The topic was cleared."
    else
      "The topic was changed to: #{topic}"
    message = App.SystemMessage.createFromConversation(@, localText: text)
    @didReceiveMessage(message, suppressNotifications: true)
  ).observes('topic')

  updateName: (newName) ->
    if @isPropertyLocked('name')
      Ember.Logger.warn "I can't change the name of a group when I'm still waiting for a response from the server."
      return

    data =
      name: newName
    oldName = @get('name')
    url = App.get('api').buildURL("/groups/#{@get('id')}/update")
    @withLockedPropertyTransaction url, 'POST', { data: data }, 'name', =>
      @set('name', newName)
    , =>
      @set('name', oldName)

  updateTopic: (newTopic) ->
    if @isPropertyLocked('topic')
      Ember.Logger.warn "I can't change the topic of a group when I'm still waiting for a response from the server."
      return

    data =
      topic: newTopic
    oldTopic = @get('topic')
    url = App.get('api').buildURL("/groups/#{@get('id')}/update")
    @withLockedPropertyTransaction url, 'POST', { data: data }, 'topic', =>
      @set('topic', newTopic)
    , =>
      @set('topic', oldTopic)

  updateServerAllMessagesEmail: (newIsEnabled) ->
      # If the property is locked, we're currently sending it.
      return if @isPropertyLocked('serverAllMessagesEmail')

      oldValue = @get('serverAllMessagesEmail')

      data =
        server_all_messages_email: newIsEnabled
      api = App.get('api')
      url = api.buildURL("/groups/#{@get('id')}/user_group_preferences/update")
      @withLockedPropertyTransaction url, 'POST', { data: data }, 'serverAllMessagesEmail', =>
        @set('serverAllMessagesEmail', newIsEnabled)
      , =>
        @set('serverAllMessagesEmail', oldValue)

  scheduleLoadUserGroupPreferences: ->
    return if @get('isUserGroupPreferencesLoaded')
    return if @get('loadUserGroupPreferencesTimer')?
    @set('loadUserGroupPreferencesTimer', Ember.run.later(@, '_loadUserGroupPreferences', 10000))

  _loadUserGroupPreferences: ->
    @set('loadUserGroupPreferencesTimer', null)
    @loadUserGroupPreferences()

  loadUserGroupPreferences: ->
    return if @get('isLoadingUserGroupPreferences')
    return if @get('isUserGroupPreferencesLoaded')

    @set('isLoadingUserGroupPreferences', true)
    api = App.get('api')
    api.ajax(api.buildURL("/groups/#{@get('id')}/user_group_preferences"), 'GET', {})
    .always =>
      @set('isLoadingUserGroupPreferences', false)
    .then (json) =>
      if ! json? || json.error?
        throw json
      json = Ember.makeArray(json)
      prefsJson = json.find (o) -> o.object_type == 'user_group_preferences'
      if prefsJson?
        @setProperties
          serverAllMessagesEmail: prefsJson.server_all_messages_email
          isUserGroupPreferencesLoaded: true
    .catch App.rejectionHandler

  fetchUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}")

  updateUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/update")

  earlierMessagesUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/messages")

  publishMessageWithAttachmentUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/messages/create")

  publishMessageChannelName: ->
    "/groups/#{@get('id')}/messages"

  updateAvatarUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/update")

  updateWallpaperUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/update")

  reload: ->
    id = @get('id')
    if ! id?
      throw new Error("Can't reload a record when it doesn't have an id.")

    reloadingPromise = @get('isReloading')
    if reloadingPromise
      Ember.Logger.info "Already reloading #{@constructor}:#{@get('id')}; ignoring."
      return reloadingPromise

    promise = @constructor.fetchAndLoadSingle(id).always =>
      @set('isReloading', null)
    @set('isReloading', promise)

    promise


App.Group.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  _allActive: null

  initialFetchLimit: 40

  propertiesFromRawAttrs: (json) ->
    api = App.get('api')
    lastActiveAt = api.deserializeUnixTimestamp(json.last_message_at)
    # Treat room creation as activity.
    lastActiveAt ?= api.deserializeUnixTimestamp(json.created_at)

    id: App.BaseModel.coerceId(json.id)
    name: json.name
    joinUrl: json.join_url
    topic: json.topic
    avatarUrl: App.UrlUtil.mediaUrlToHttps(json.avatar_url)
    wallpaperUrl: App.UrlUtil.mediaUrlToHttps(json.wallpaper_url)
    adminIds: (json.admin_ids ? []).map (id) -> App.BaseModel.coerceId(id)
    memberIds: (json.member_ids ? []).map (id) -> App.BaseModel.coerceId(id)
    lastActiveAt: lastActiveAt
    lastSeenRank: json.last_seen_rank

  # Fetches a Group by id and returns a promise that resolves to the Group
  # instance.
  fetchAndLoadSingle: (id) ->
    @fetchById(id)
    .then (json) =>
      if ! json? || json.error?
        throw json
      return @loadSingle(json)
    .catch App.rejectionHandler

  # Given json for a Group and all its associations, load it, and return the
  # `App.Group` instance.
  loadSingle: (json) ->
    instances = App.loadAll(json)
    group = instances.find (o) -> o instanceof App.Group
    group.didLoadMembers()
    if ! group.hasLoadedMessagesFromServer()
      messages = instances.filter (o) -> o instanceof App.Message
      # Prepend so that any system messages are shown at the end.
      group.get('messages').replace(0, 0, messages)
      if ! group.get('lastActiveAt')?
        dates = messages.mapBy('createdAt').compact()
        newActiveAt = dates.reduce (max,date) ->
          if ! max? || date.getTime() > max.getTime()
            date
          else
            max
        , null
        group.set('lastActiveAt', newActiveAt)

    group

  fetchById: (id) ->
    api = App.get('api')
    data =
      limit: App.Group.initialFetchLimit
    api.ajax(api.buildURL("/groups/#{id}"), 'GET', data: data)

  fetchByJoinCode: (joinCode) ->
    api = App.get('api')
    data =
      join_code: joinCode
      limit: App.Group.initialFetchLimit
    api.ajax(api.buildURL('/groups/find'), 'GET', data: data)

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

  parseJoinCode: (str) ->
    joinCode = str ? ''
    joinCode = joinCode.trim()
    return null if Ember.isEmpty(joinCode)

    matches = joinCode.match(/^[^\?]*\/join\/([a-zA-Z0-9]+)/)
    if matches
      # If we were given a URL, strip out the join code.
      joinCode = matches[1]
    else if (matches = /^[^\?]*\/view\/([a-zA-Z0-9\-]+)/.exec(joinCode))
      # Fall back to Group id from room permalink.  Don't allow 1-1 id.
      joinCode = matches[1] if matches[1]? && matches[1].indexOf('-') == -1

    joinCode
