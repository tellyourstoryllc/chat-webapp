#= require base-model

App.Group = App.BaseModel.extend

  # New message draft temporarily stored before sending.
  newMessageText: ''

  # New message file temporarily stored before sending.
  newMessageFile: null

  init: ->
    @_super(arguments...)
    @setProperties
      messages: []
      memberIds: []
      notificationResults: []

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
    # Make sure the sender is loaded before displaying it.
    message.loadAssociations()
    .then (newlyLoadedMessages) =>
      # If the group and its messages were newly fetched, don't add the message
      # since it will be a dupe.
      if ! newlyLoadedMessages
        @get('messages').pushObject(message)

      wasMentioned = message.doesMentionUser(App.get('currentUser'))
      if wasMentioned
        # The current user was mentioned.  Play sound.
        @playMentionSound()

      if message.get('userId') != App.get('currentUser.id') &&
      (! App.get('hasFocus') || App.get('currentlyViewingRoom') != @)
        # Notify of new message.
        @notifyOfNewMessage(message, wasMentioned)

    true

  playMentionSound: ->
    return unless Modernizr.audio
    audio = $('.mention-sound').get(0)
    audio.currentTime = 0 if audio.currentTime > 0
    audio.play()

  notifyOfNewMessage: (message, wasMentioned) ->
    # if ! wasMentioned
    #   # Play regular new message sound.

    # Create a desktop notification.
    notif = message.toNotification()
    title = notif.title
    delete notif.title
    result = window.notify.createNotification(title, notif)
    @get('notificationResults').pushObject(result)


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
