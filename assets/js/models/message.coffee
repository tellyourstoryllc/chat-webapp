App.Message = Ember.Object.extend()


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
      promise = api.ajax(api.buildURL("/groups/#{groupId}/messages/create"), 'POST', data: data)
    else
      # Publish the message via the socket.
      promise = App.get('fayeClient').publish("/groups/#{groupId}/messages/create", data)

    promise.then (json) =>
      if ! json? || json.error?
        # Reject the promise.
        throw json
      else
        json = Ember.makeArray(json)
        msgAttrs = json.find (o) -> o.object_type == 'message'
        # Update the Message instance.
        message.setProperties(@propertiesFromRawAttrs(msgAttrs))
        # Save to our identity map.
        @_all.pushObject(message)
        @_allById[message.get('id')] = message

        return message
