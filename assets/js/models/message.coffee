#= require base-model

App.Message = App.BaseModel.extend

  group: (->
    App.Group.lookup(@get('groupId'))
  ).property('groupId')

  user: (->
    App.User.lookup(@get('userId'))
  ).property('userId')

  # This is here to add an extra dependent key on the emoticons version.
  body: (->
    @get('text')
  ).property('App.emoticonsVersion', 'text')

  toNotification: ->
    userName = @get('user.name') ? "User #{@get('userId')}"
    roomName = @get('group.name') ? "Room #{@get('groupId')}"

    # TODO: icon field.
    tag: @get('id')
    title: "#{userName} | #{roomName}"
    body: @get('text')
    icon: {}


App.Message.reopenClass

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  all: -> @_all

  loadRaw: (json) ->
    props = @propertiesFromRawAttrs(json)

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
    api = App.get('api')

    id: App.BaseModel.coerceId(json.id)
    groupId: App.BaseModel.coerceId(json.group_id)
    userId: App.BaseModel.coerceId(json.user_id)
    text: json.text
    imageUrl: json.image_url
    createdAt: api.deserializeUnixTimestamp(json.created_at)

  # Returns Promise.
  sendNewMessage: (message) ->
    groupId = message.get('groupId')
    data = {}
    for key in ['text', 'imageFile']
      val = message.get(key)
      if val?
        data[key.underscore()] = val

    # Update instance state.
    message.set('isSaving', true)

    # Only send message via POST if there's an image.
    if message.get('imageFile')?
      api = App.get('api')
      api.ajax(api.buildURL("/groups/#{groupId}/messages/create"), 'POST', data: data)
      .then (json) =>
        Ember.Logger.log "message create response", json
        if ! json? || json.error?
          # Reject the promise.
          throw json
        else
          json = Ember.makeArray(json)
          msgAttrs = json.find (o) -> o.object_type == 'message'
          @didCreateRecord(message, msgAttrs)

          return message
    else
      # The instance is used by the faye extension.
      data.messageInstance = message
      # Publish the message via the socket.
      App.get('fayeClient').publish("/groups/#{groupId}/messages", data)

  didCreateRecord: (message, attrs) ->
    hadId = message.get('id')?
    # Update the Message instance.
    props = @propertiesFromRawAttrs(attrs)
    # Update state.
    props.isLoaded = true
    props.isSaving = false
    message.setProperties(props)

    if ! hadId && message.get('id')?
      # Save to our identity map.
      @_all.pushObject(message)
      @_allById[message.get('id')] = message
