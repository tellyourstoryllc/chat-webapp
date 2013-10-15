#= require base-model

App.Group = Ember.Object.extend()


App.Group.reopenClass

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  all: -> @_all

  loadRaw: (json) ->
    props =
      id: if json.id? then "#{json.id}" else null
      name: json.name
      joinUrl: json.join_url
      topic: json.topic

    prevInst = props.id? && @_allById[props.id]
    if prevInst?
      prevInst.setProperties(props)
      inst = prevInst
    else
      inst = App.Group.create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst

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
