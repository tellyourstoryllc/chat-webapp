#= require base-model

App.User = App.BaseModel.extend App.LockableApiModelMixin,

  # Most recently calculated idle duration in seconds.
  mostRecentIdleDuration: null

  # Status icon duck typing.
  hasStatusIcon: true

  isContact: false

  # Account object.
  _account: null

  defaultAvatarUrl: App.webServerUrl('imageAvatar')

  avatarUrl: Ember.computed.defaultTo('defaultAvatarUrl')

  oneToOneWallpaperUrl: Ember.computed.alias('account.oneToOneWallpaperUrl')

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

  account: (->
    account = @get('_account')
    return account if account?
    account = App.Account.lookup(@get('id'))
    @set('_account', account)
    account
  ).property('_account')

  isInternal: (->
    name = @get('name')
    return false unless name?
    name[0] == '_'
  ).property('name')

  mentionName: (->
    @get('name').replace(/\s/g, '')
  ).property('name')

  # Array of lowercase strings that this user should be suggested for when
  # autocompleting.
  suggestFor: (->
    name = @get('name')
    [@get('mentionName'), name].concat(name.split(/\s+/))
    .map((s) -> s.toLowerCase())
    .uniq()
  ).property('mentionName', 'name')

  shouldDisplayIdleDuration: (->
    @get('clientType') not in ['phone', 'tablet'] && @get('status') == 'idle'
  ).property('clientType', 'status')

  idleDurationAsOfNow: (now = null) ->
    seconds = @get('idleDuration')
    asOf = @get('idleDurationReceivedAt')
    return null unless seconds? && asOf?
    now ?= new Date()
    seconds + (now.getTime() - asOf.getTime()) / 1000

  avatarUrlChanged: (->
    id = @get('id')
    return unless id?
    $(".sent-by-#{id} .small-avatar").prop('src', @get('avatarUrl'))
  ).observes('id', 'avatarUrl')

  oneToOneUrlPath: (->
    id = App.OneToOne.idFromUser(@)
    return null unless id?
    "/view/#{id}"
  ).property('id')


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
    avatarUrl: App.UrlUtil.mediaUrlToHttps(json.avatar_url)
    name: json.username # Note: we're ignoring the `user.name` field.
    clientType: json.client_type
    status: json.status
    statusText: json.status_text
    idleDuration: json.idle_duration
    idleDurationReceivedAt: new Date()
    mostRecentIdleDuration: json.idle_duration

  fetchById: (id) ->
    ids = Ember.makeArray(id)
    api = App.get('api')
    data =
      ids: ids.join(',')
    api.ajax(api.buildURL("/users"), 'GET', data: data)

  userMentionedInGroup: (name, groupOrUsers) ->
    lowerCaseName = name.toLowerCase()
    users = if groupOrUsers instanceof App.Group
      groupOrUsers.get('members')
    else
      groupOrUsers
    users.find (u) => u.get('mentionName').toLowerCase() == lowerCaseName

  allArrangedById: ->
    @_allArranged ?= App.RecordArray.create
      type: @
      content: @_all
      sortProperties: ['id']

  allArrangedByName: ->
    @_allArranged ?= App.RecordArray.create
      type: @
      content: @_all
      sortProperties: ['name']
