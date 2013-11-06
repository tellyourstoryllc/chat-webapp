#= require base-model
#= require conversation

App.OneToOne = App.BaseModel.extend App.Conversation, App.LockableApiModelMixin,

  name: (->
    # TODO
    null
  ).property()

  otherUserId: (->
    id = @get('id')
    return null unless id?
    currentUserId = App.get('currentUser.id')
    return null unless currentUserId?
    ids = id.split(/-/)
    ids.find (id) -> id != currentUserId
  ).property('App.currentUser.id', 'id')

  otherUser: (->
    id = @get('otherUserId')
    return null unless id?
    App.User.lookup(id)
  ).property('otherUserId', 'usersLoaded')

  isSubscribedToUpdates: true

  subscribeToMessages: ->
    # Ignore.  Assume we're already listening on the user channel.

  mostRecentMessagesUrl: (->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages")
  ).property('id')

  earlierMessagesUrl: (->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages")
  ).property('id')

  publishMessageWithAttachmentUrl: ->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages/create")

  publishMessageChannelName: ->
    "/users/#{@get('otherUserId')}"


App.OneToOne.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    id: @coerceId(json.id)
    memberIds: (json.member_ids ? []).map (id) -> @coerceId(id)

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
