#= require base-model

App.Emoticon = App.BaseModel.extend()


App.Emoticon.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  # Identity map of model instances by name.
  _allByName: {}

  _allArranged: null

  # Note: this differs from the base class in that it has an identity map by
  # name.
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
      @_allByName[props.name] = inst
      isNew = true

    [inst, isNew]

  # Note: this differs from the base class in that it has an identity map by
  # name.
  discardRecords: (instances) ->
    throw "discardRecords not implemented for App.Emoticon"

  propertiesFromRawAttrs: (json) ->
    api = App.get('api')

    id: App.BaseModel.coerceId(json.id)
    name: json.name
    imageUrl: App.UrlUtil.mediaUrlToHttps(json.image_url)

  lookupByName: (name) ->
    @_allByName[name]

  allArranged: ->
    @_allArranged ?= App.RecordArray.create
      type: @
      content: @_all
      sortProperties: ['name']

  replaceText: (text, emoticonReplacementFn) ->
    @all().reduce (str, emoticon) ->
      regexp = new RegExp(App.Util.escapeRegexp(emoticon.get('name')), 'g')
      replacement = emoticonReplacementFn(str, emoticon)
      str.replace regexp, replacement
    , text

  asHtml: (text, options = {}) ->
    escape = Ember.Handlebars.Utils.escapeExpression
    classNames = Ember.makeArray(options.classNames).join(' ')
    @replaceText escape(text), (str, emoticon) ->
      "<img class='emoticon #{escape(classNames)}' src='#{emoticon.get('imageUrl')}'" +
      " title='#{escape(emoticon.get('name'))}'>"
    .htmlSafe()
