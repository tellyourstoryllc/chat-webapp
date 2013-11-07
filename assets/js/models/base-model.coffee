App.BaseModel = Ember.Object.extend

  isLoading: false
  isLoaded: false
  isSaving: false
  isError: false
  isDeleted: false


App.BaseModel.reopenClass

  coerceId: (id) ->
    if id? then "#{id}" else null

  all: -> @_all

  loadRawWithMetaData: (json) ->
    props = @propertiesFromRawAttrs(json)
    props.isLoaded ?= true

    prevInst = props.id? && @_allById[props.id]
    if prevInst?
      prevInst.setProperties(props)
      inst = prevInst
      isNew = false
    else
      inst = @create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst
      isNew = true

    [inst, isNew]

  loadRaw: (json) ->
    [instance] = @loadRawWithMetaData(arguments...)
    instance

  lookup: (id) ->
    @_allById[App.BaseModel.coerceId(id)]

  exists: (id) ->
    @lookup(id)?

  # Removes given instances from our store.  Does not modify instances.
  discardRecords: (instances) ->
    for instance in Ember.makeArray(instances)
      # Only discard records of this type.
      continue if instance not instanceof @

      id = instance.get('id')
      delete @_allById[id] if id?
      # TODO: This is linear on all our objects...
      @_all.removeObject(instance)

    undefined
