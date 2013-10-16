#= require base-model

App.Group = App.BaseModel.extend

  # New message draft temporarily stored before sending.
  newMessageText: ''

  init: ->
    @_super(arguments...)
    @setProperties
      messages: []
      memberIds: []

  # Note: Can't have dependent key on memberIds.@each since the members are
  # primitives, not objects, and you can't observe a primitive.
  members: (->
    @get('memberIds').map (id) -> App.User.lookup(id)
  ).property('memberIds.@each')

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
          message = App.Message.loadRaw(json)
          @didReceiveMessage(message)
    @set('subscription', subscription)

  didReceiveMessage: (message) ->
    @get('messages').pushObject(message)

    if message.get('userId') != App.get('currentUser.id')
      # Notify of new message.
      notif = message.toNotification()
      title = notif.title
      delete notif.title
      window.notify.createNotification(title, notif)

    true


App.Group.reopenClass

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  all: -> @_all

  loadRaw: (json) ->
    props = @propertiesFromRawAttrs(json)
    props.isLoaded = true

    prevInst = props.id? && @_allById[props.id]
    if prevInst?
      prevInst.setProperties(props)
      inst = prevInst
    else
      inst = @create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst

  propertiesFromRawAttrs: (json) ->
    id: App.BaseModel.coerceId(json.id)
    name: json.name
    joinUrl: json.join_url
    topic: json.topic
    memberIds: (json.member_ids ? []).map (id) -> App.BaseModel.coerceId(id)

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
    api.ajax(api.buildURL("/groups/#{id}"), 'GET', {})

  lookup: (id) ->
    @_allById[App.BaseModel.coerceId(id)]
