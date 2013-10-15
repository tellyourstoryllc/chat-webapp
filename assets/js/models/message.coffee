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
