#= require base-model
#= require conversation

App.Group = App.BaseModel.extend App.Conversation, App.LockableApiModelMixin,

  # Faye subscription to listen for updates.
  subscription: null

  # Show the UI to set topics.
  canSetTopic: true

  isCurrentUserAdmin: (->
    @get('adminIds').contains(App.get('currentUser.id'))
  ).property('App.currentUser.id', 'adminIds.@each')

  isNameLocked: (->
    @isPropertyLocked('name')
  ).property('_lockedProperties.@each')

  isSubscribedToUpdates: (->
    @get('subscription')?
  ).property('subscription')

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

    subscription = client.subscribe "/groups/#{groupId}/messages", (json) =>
      Ember.run @, ->
        @didReceiveUpdateFromFaye(json)
    @set('subscription', subscription)

    return subscription

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

  mostRecentMessagesUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/messages")

  earlierMessagesUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/messages")

  publishMessageWithAttachmentUrl: ->
    App.get('api').buildURL("/groups/#{@get('id')}/messages/create")

  publishMessageChannelName: ->
    "/groups/#{@get('id')}/messages"

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

  propertiesFromRawAttrs: (json) ->
    id: App.BaseModel.coerceId(json.id)
    name: json.name
    joinUrl: json.join_url
    topic: json.topic
    adminIds: (json.admin_ids ? []).map (id) -> App.BaseModel.coerceId(id)
    memberIds: (json.member_ids ? []).map (id) -> App.BaseModel.coerceId(id)

  # Fetches a Group by id and returns a promise that resolves to the Group
  # instance.
  fetchAndLoadSingle: (id) ->
    @fetchById(id)
    .then (json) =>
      if ! json? || json.error?
        throw json
      return @loadSingle(json)
    .then null, App.rejectionHandler

  # Given json for a Group and all its associations, load it, and return the
  # `App.Group` instance.
  loadSingle: (json) ->
    instances = App.loadAll(json)
    group = instances.find (o) -> o instanceof App.Group
    group.didLoadMembers()
    if Ember.isEmpty(group.get('messages'))
      group.set('messages', instances.filter (o) -> o instanceof App.Message)

    group

  fetchById: (id) ->
    api = App.get('api')
    data =
      limit: 40
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
