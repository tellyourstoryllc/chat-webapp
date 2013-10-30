#= require base-model

App.User = App.BaseModel.extend

  # Most recently calculated idle duration in seconds.
  mostRecentIdleDuration: null

  isIdle: Ember.computed.equal('status', 'idle')

  # TODO: this should take into account device status.
  computedStatus: (->
    @get('status')
  ).property('status')

  sortableComputedStatus: (->
    switch @get('computedStatus')
      when 'available'
        0
      when 'away'
        1
      when 'do_not_disturb'
        2
      else
        3
  ).property('computedStatus')

  mentionName: (->
    @get('name').replace(/\s/g, '')
  ).property('name')

  # Array of lowercase strings that this user should be suggested for when
  # autocompleting.
  suggestFor: (->
    [@get('mentionName')].concat(@get('name').split(/\s+/))
    .map (s) -> s.toLowerCase()
  ).property('mentionName', 'name')

  idleDurationAsOfNow: (now = null) ->
    seconds = @get('idleDuration')
    asOf = @get('idleDurationReceivedAt')
    return null unless seconds? && asOf?
    now ?= new Date()
    seconds + (now.getTime() - asOf.getTime()) / 1000


App.User.reopenClass

  statuses: [
    Ember.Object.create(title: 'Available', name: 'available')
    Ember.Object.create(title: 'Away', name: 'away')
    Ember.Object.create(title: 'Do not disturb', name: 'do_not_disturb')
  ]

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
    idleDuration: json.idle_duration
    idleDurationReceivedAt: new Date()
    mostRecentIdleDuration: json.idle_duration

  userMentionedInGroup: (name, groupOrUsers) ->
    lowerCaseName = name.toLowerCase()
    users = if groupOrUsers instanceof App.Group
      groupOrUsers.get('members')
    else
      groupOrUsers
    users.find (u) => u.get('mentionName').toLowerCase() == lowerCaseName
