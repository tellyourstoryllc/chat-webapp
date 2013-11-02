#= require base-model

App.Emoticon = App.BaseModel.extend

  imageUrl: (->
    imageData = @get('imageData')

    if imageData?
      "data:image/png;base64," + imageData
    else
      null
  ).property('imageData')


App.Emoticon.reopenClass

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  # Identity map of model instances by name.
  _allByName: {}

  _allArranged: null

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
      @_allByName[props.name] = inst

    inst

  propertiesFromRawAttrs: (json) ->
    api = App.get('api')

    id: App.BaseModel.coerceId(json.id)
    name: json.name
    imageData: json.image_data

  lookupByName: (name) ->
    @_allByName[name]

  allArranged: ->
    @_allArranged ?= App.RecordArray.create
      type: @
      content: @_all
      sortProperties: ['name']
