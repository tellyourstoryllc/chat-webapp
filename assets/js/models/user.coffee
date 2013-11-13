#= require base-model

App.User = App.BaseModel.extend App.LockableApiModelMixin,

  # Most recently calculated idle duration in seconds.
  mostRecentIdleDuration: null

  # Status icon duck typing.
  hasStatusIcon: true

  isIdle: Ember.computed.equal('status', 'idle')

  computedStatus: (->
    clientType = @get('clientType')
    return clientType if clientType in ['mobile', 'phone', 'tablet']
    @get('status')
  ).property('clientType', 'status')

  sortableComputedStatus: (->
    switch @get('status')
      when 'available'
        0
      when 'away', 'idle'
        1
      when 'do_not_disturb'
        2
      else
        3
  ).property('status')

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

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    id: App.BaseModel.coerceId(json.id)
    avatarUrl: json.avatar_url
    name: json.name
    clientType: json.client_type
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

  allArrangedByName: ->
    @_allArranged ?= App.RecordArray.create
      type: @
      content: @_all
      sortProperties: ['name']
