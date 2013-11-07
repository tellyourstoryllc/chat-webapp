#= require base-model
#= require conversation

App.OneToOne = App.BaseModel.extend App.Conversation, App.LockableApiModelMixin,

  name: Ember.computed.alias('otherUser.name')

  # OneToOnes don't have topics.
  canSetTopic: false

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
    # Ignore.  Assume we're already listening on the user channel.

  mostRecentMessagesUrl: ->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages")

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

    @constructor.fetchAndLoadSingle(id)


App.OneToOne.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    id: @coerceId(json.id)
    memberIds: (json.member_ids ? []).map (id) -> @coerceId(id)

  lookupOrCreate: (id) ->
    id = @coerceId(id)

    inst = @lookup(id)
    return inst if inst?

    inst = @create(id: id, memberIds: @userIdsFromId(id) ? [])
    # Save to our identity map.
    @_all.pushObject(inst)
    @_allById[id] = inst

    inst

  # Lookup by id.  If we don't have it, fetch and load.  Returns a promise that
  # resolves to the model instance.
  find: (id) ->
    new Ember.RSVP.Promise (resolve, reject) =>
      inst = @lookup(id)
      if inst?
        resolve(inst)
      else
        resolve(@fetchAndLoadSingle(id))

  # Fetches a OneToOne by id and returns a promise that resolves to the OneToOne
  # instance.
  fetchAndLoadSingle: (id) ->
    @fetchById(id)
    .then (json) =>
      if ! json? || json.error?
        throw json
      return @loadSingle(json)

  fetchById: (id) ->
    api = App.get('api')
    data =
      limit: 100
    api.ajax(api.buildURL("/one_to_ones/#{id}"), 'GET', data: data)

  # Given json for a OneToOne and all its associations, load it, and return the
  # `App.OneToOne` instance.
  loadSingle: (json) ->
    instances = App.loadAll(json)
    oneToOne = instances.find (o) -> o instanceof App.OneToOne
    oneToOne.didLoadMembers()
    if Ember.isEmpty(oneToOne.get('messages'))
      oneToOne.set('messages', instances.filter (o) -> o instanceof App.Message)

    oneToOne

  idFromUserIds: (userId1, userId2) ->
    return null unless userId1? && userId2?
    id1 = parseInt(userId1)
    id2 = parseInt(userId2)
    ids = if id1 < id2 then [id1, id2] else [id2, id1]
    ids.join('-')

  idFromUser: (user) ->
    @idFromUserIds(user.get('id'), App.get('currentUser.id'))

  userIdsFromId: (id) ->
    return [] unless id?
    id.split(/-/)
