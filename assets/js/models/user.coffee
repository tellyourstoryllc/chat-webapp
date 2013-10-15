App.User = Ember.Object.extend()

App.User.reopenClass

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  loadRaw: (json) ->
    props =
      id: if json.id? then "#{json.id}" else null
      name: json.name
      status: json.status
      statusText: json.status_text

    prevInst = props.id? && @_allById[props.id]
    if prevInst?
      prevInst.setProperties(props)
      inst = prevInst
    else
      inst = App.User.create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst
