App.BaseModel = Ember.Object.extend Ember.Evented,

  isLoading: false
  isLoaded: false
  isSaving: false
  isError: false
  isDeleted: false
  isReloading: false


App.BaseModel.reopenClass

  coerceId: (id) ->
    if id? then "#{id}" else null

  all: -> @_all

  # Given object properties, load it into our store.  Return instance with
  # metadata.
  loadWithMetaData: (props) ->
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

  # Given object properties, load it into our store.  Return instance only.
  load: (props) ->
    [instance] = @loadWithMetaData(arguments...)
    instance

  # Given raw JSON object, load it into our store.  Return instance with
  # metadata.
  loadRawWithMetaData: (json) ->
    @loadWithMetaData(@propertiesFromRawAttrs(json))

  # Given raw JSON object, load it into our store.  Return instance only.
  loadRaw: (json) ->
    [instance] = @loadRawWithMetaData(arguments...)
    instance

  lookup: (id) ->
    @_allById[App.BaseModel.coerceId(id)]

  exists: (id) ->
    @lookup(id)?

  # Lookup by id.  If we don't have it, fetch and load.  Returns a promise that
  # resolves to the model instance.  Requires that `fetchById()` be implemented.
  find: (id) ->
    new Ember.RSVP.Promise (resolve, reject) =>
      inst = @lookup(id)
      if inst?
        resolve(inst)
      else
        resolve(@fetchAndLoadSingle(id))

  # Fetches a record by id and returns a promise that resolves to the record
  # instance.  Requires that `fetchById()` be implemented.
  fetchAndLoadSingle: (id) ->
    @fetchById(id)
    .then (json) =>
      if ! json? || json.error?
        throw json
      instance = @loadSingle(json)
      # If we weren't able to load an object of this type, then reject the
      # promise.
      throw json if ! instance?

      return instance
    .catch App.rejectionHandler

  # Given json for a record and all its associations, load it, and return the
  # instance.
  loadSingle: (json) ->
    instances = App.loadAll(json)
    instances.find (o) => o instanceof @

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
