#= require base-model
#= require conversation

App.Group = App.BaseModel.extend App.Conversation, App.LockableApiModelMixin,

  # Faye subscription to listen for updates.
  subscription: null

  isCurrentUserAdmin: (->
    @get('adminIds').contains(App.get('currentUser.id'))
  ).property('App.currentUser.id', 'adminIds.@each')

  isNameLocked: (->
    @isPropertyLocked('name')
  ).property('_lockedProperties.@each')

  isSubscribedToUpdates: (->
    @get('subscription')?
  ).property('subscription')

  close: ->
    @_super(arguments...)
    @cancelMessagesSubscription()
    # TODO: Discard message records.
    @setProperties
      newMessageText: ''
      newMessageFile: null
      usersLoaded: false
      messages: []
      canLoadEarlierMessages: true

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
        @didReceiveUpdateFromFaye(json)
    @set('subscription', subscription)

  mostRecentMessagesUrl: (->
    App.get('api').buildURL("/groups/#{@get('id')}/messages")
  ).property('id')

  earlierMessagesUrl: (->
    App.get('api').buildURL("/groups/#{@get('id')}/messages")
  ).property('id')


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

    group

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
