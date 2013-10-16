#= require base-model

App.Group = App.BaseModel.extend

  init: ->
    @_super(arguments...)
    @set('messages', [])

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
      Ember.Logger.log "received packet", json
      if ! json?.error? && json.object_type == 'message'
        # We received a new message.
        message = App.Message.loadRaw(json)
        @didReceiveMessage(message)
    @set('subscription', subscription)

  didReceiveMessage: (message) ->
    @get('messages').pushObject(message)
    # TODO: notify the user of new message.



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
      inst = App.Group.create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst

  propertiesFromRawAttrs: (json) ->
    id: if json.id? then "#{json.id}" else null
    name: json.name
    joinUrl: json.join_url
    topic: json.topic

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
