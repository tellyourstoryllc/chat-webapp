#= require base-model

App.User = App.BaseModel.extend()

App.User.reopenClass

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
      inst = App.User.create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst

  lookup: (id) ->
    @_allById[App.BaseModel.coerceId(id)]

  propertiesFromRawAttrs: (json) ->
    id: App.BaseModel.coerceId(json.id)
    name: json.name
    status: json.status
    statusText: json.status_text

  userMentionedInGroup: (name, groupOrUsers) ->
    lowerCaseName = name.toLowerCase()
    users = if groupOrUsers instanceof App.Group
      groupOrUsers.get('members')
    else
      groupOrUsers
    users.find (u) ->
      realName = u.get('name').replace(/\s/g, '')
      realName.toLowerCase() == lowerCaseName
