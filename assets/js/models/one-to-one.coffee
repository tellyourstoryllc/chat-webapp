#= require base-model
#= require conversation

App.OneToOne = App.BaseModel.extend App.Conversation, App.LockableApiModelMixin,

  name: Ember.computed.alias('otherUser.name')

  avatarUrl: Ember.computed.alias('otherUser.avatarUrl')

  wallpaperUrl: Ember.computed.alias('otherUser.oneToOneWallpaperUrl')

  hasStatusIcon: Ember.computed.alias('otherUser.hasStatusIcon')

  clientType: Ember.computed.alias('otherUser.clientType')

  status: Ember.computed.alias('otherUser.status')

  statusText: Ember.computed.alias('otherUser.statusText')

  # OneToOnes don't have topics.
  canSetTopic: false

  isCurrentUserAdmin: false

  otherUserId: (->
    id = @get('id')
    return null unless id?
    currentUserId = App.get('currentUser.id')
    return null unless currentUserId?
    ids = id.split(/-/)
    return null unless ids.length >= 2

    # This intentionally only compares the first id with the current user's id
    # so that we allow 1-1 with yourself.
    if ids[0] == currentUserId
      ids[1]
    else
      ids[0]
  ).property('App.currentUser.id', 'id')

  otherUser: (->
    id = @get('otherUserId')
    return null unless id?
    App.User.lookup(id)
  ).property('otherUserId', 'usersLoaded')

  isSubscribedToUpdates: true

  subscribeToMessages: ->
    # Assume we're already listening on the user channel.  Return that.
    App.get('userChannelSubscription')

  willSendMessageToChannel: (message, data) ->
    # For OneToOnes, the server expects us to set the action.
    data.ext ?= {}
    data.ext.action = 'create_one_to_one_message'

  fetchUrl: ->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}")

  updateUrl: ->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/update")

  earlierMessagesUrl: ->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages")

  publishMessageWithAttachmentUrl: ->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages/create")

  publishMessageChannelName: ->
    "/users/#{@get('otherUserId')}"

  reload: ->
    id = @get('id')
    if ! id?
      throw new Error("Can't reload a record when it doesn't have an id.")

    @set('isReloading', true)
    @constructor.fetchAndLoadSingle(id)
    .always =>
      @set('isReloading', false)


App.OneToOne.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    id: @coerceId(json.id)
    memberIds: (json.member_ids ? []).map (id) => @coerceId(id)
    lastActiveAt: App.get('api').deserializeUnixTimestamp(json.last_message_at)
    lastSeenRank: json.last_seen_rank

  lookupOrCreate: (id) ->
    id = @coerceId(id)

    inst = @lookup(id)
    return inst if inst?

    inst = @create(id: id, memberIds: @userIdsFromId(id) ? [])
    # Save to our identity map.
    @_all.pushObject(inst)
    @_allById[id] = inst

    inst

  # Fetches a OneToOne by id and returns a promise that resolves to the OneToOne
  # instance.  This is different from the base class since it must handle the
  # return being only Users in the case that the OneToOne hasn't been created
  # yet.
  fetchAndLoadSingle: (id) ->
    @fetchById(id)
    .then (json) =>
      if ! json? || json.error?
        throw json

      json = Ember.makeArray(json)
      # If the API didn't return a OneToOne, but only its users, then synthesize
      # one.
      if ! json.find((o) -> o.object_type == 'one_to_one')
        # Build the JSON for a one to one.
        json.push
          object_type: 'one_to_one'
          id: id
          member_ids: json.filter((o) -> o.object_type == 'user').map((o) -> o.id)
      return @loadSingle(json)
    .catch App.rejectionHandler

  fetchById: (id) ->
    api = App.get('api')
    data =
      limit: App.Group.initialFetchLimit
    api.ajax(api.buildURL("/one_to_ones/#{id}"), 'GET', data: data)

  # Given json for a OneToOne and all its associations, load it, and return the
  # `App.OneToOne` instance.
  loadSingle: (json) ->
    instances = App.loadAll(json)
    oneToOne = instances.find (o) -> o instanceof App.OneToOne
    oneToOne.didLoadMembers()
    if ! oneToOne.hasLoadedMessagesFromServer()
      messages = instances.filter (o) -> o instanceof App.Message
      # Prepend so that any system messages are shown at the end.
      oneToOne.get('messages').replace(0, 0, messages)
      if ! oneToOne.get('lastActiveAt')?
        dates = messages.mapBy('createdAt').compact()
        newActiveAt = dates.reduce (max,date) ->
          if ! max? || date.getTime() > max.getTime()
            date
          else
            max
        , null
        oneToOne.set('lastActiveAt', newActiveAt)

    oneToOne

  idFromUserIds: (id1, id2) ->
    return null unless id1? && id2?
    ids = if id1 < id2 then [id1, id2] else [id2, id1]
    ids.join('-')

  idFromUser: (user) ->
    @idFromUserIds(user.get('id'), App.get('currentUser.id'))

  userIdsFromId: (id) ->
    return [] unless id?
    id.split(/-/)
