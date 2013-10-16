App.Message = Ember.Object.extend

  user: (->
    App.User.lookup(@get('userId'))
  ).property('userId')


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
      inst = App.Message.create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst

  propertiesFromRawAttrs: (json) ->
    api = App.get('api')

    id: if json.id? then "#{json.id}" else null
    groupId: json.group_id
    userId: json.user_id
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
    message.setProperties(@propertiesFromRawAttrs(attrs))
    if ! hadId && message.get('id')?
      # Save to our identity map.
      @_all.pushObject(message)
      @_allById[message.get('id')] = message
