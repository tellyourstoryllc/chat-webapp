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
