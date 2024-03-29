parseOsFromUserAgent = ->
  # Yeah, this is complicated to get right, but it's just for segmentation so
  # it doesn't need to be 100% accurate.
  #
  # See: http://www.zytrax.com/tech/web/mobile_ids.html
  ua = navigator.userAgent
  if /iPhone/i.test(ua) || /iPad/i.test(ua) || /iPod/i.test(ua)
    os = 'ios'
  else if /Mac OS/i.test(ua) || /Macintosh/i.test(ua) || /Mac_PowerPC/i.test(ua)
    os = 'mac'
  else if /Android/i.test(ua)
    os = 'android'
  else if /Linux/i.test(ua) || /X11/i.test(ua)
    # This should come after Android since Android uses Linux in its user agent.
    os = 'linux'
  else if /Windows Phone/i.test(ua) || /Windows CE/i.test(ua)
    os = 'windows phone'
  else if /Windows/i.test(ua) || /WinNT/i.test(ua)
    # This should come after windows phone.
    os = 'windows'

  os ? 'unknown'


App.RemoteApi = Ember.Object.extend

  namespace: 'api'

  parsedOs: null

  init: ->
    @_super(arguments...)
    @set('parsedOs', parseOsFromUserAgent()) if ! @get('parsedOs')?

  defaultParams: ->
    data = {}

    token = App.get('token')
    data.token = token if token?

    # Segmentation params.
    data.client = 'web'
    data.os = @get('parsedOs')

    data

  # Returns RSVP.Promise.
  ajax: (url, type, hash) ->
    return new Ember.RSVP.Promise (resolve, reject) =>
      hash ||= {}
      hash.url = url
      hash.type = type
      hash.dataType = 'json'
      hash.context = App

      # Add in default params for all API requests.
      hash.data ?= {}
      if hash._appUseDefaults != false
        _.extend hash.data, @defaultParams()
      delete hash._appUseDefaults

      if hash.data && type != 'GET'
        hash.contentType ?= 'application/json; charset=utf-8'
        hash.data = JSON.stringify(hash.data) if hash.processData != false

      hash.success = (json) ->
        Ember.run(null, resolve, json)

      hash.error = (jqXHR, textStatus, errorThrown) =>
        Ember.run @, ->
          try
            # Global ajax request filters.
            if ! hash.skipLogOutOnInvalidTokenFilter
              @logOutOnInvalidTokenFilter(resolve, reject, jqXHR)
          catch e
            Ember.Logger.error "Error in ajax filter", e, e?.message, e?.stack ? e?.stacktrace

          reject(jqXHR)

      Ember.$.ajax(hash)

  # Wraps jQuery.ajax returning an RSVP.Promise, but is lower-level than
  # `ajax()` and doesn't muck with your params (other than the callbacks).
  rawPromisedAjax: (ajaxOptions) ->
    new Ember.RSVP.Promise (resolve, reject) =>
      Ember.$.ajax(_.extend(ajaxOptions,
        success: (result) =>
          Ember.run null, resolve, result
        error: (xhr) =>
          Ember.run null, reject, xhr
      ))

  buildURL: (url) ->
    if url? && url[0] != '/'
      url = '/' + url

    url = [@get('namespace'), url].compact().join('')
    url = '/' + url if url[0] != '/'

    url = App.webServerUrl(url)

    url

  logOutOnInvalidTokenFilter: (resolve, reject, jqXHR) ->
    if jqXHR.status == 401 && App.get('_isLoggedIn')
      App._getRouter().transitionTo('logout')

  checkin: (data) ->
    api = App.get('api')
    api.ajax(api.buildURL('/checkin'), 'POST', data: data)
    .then (json) =>
      if ! json? || json.error?
        throw json
      else
        json = Ember.makeArray(json)

        objs = json.filter (o) -> o.object_type == 'emoticon'
        emoticons = objs.map (o) -> App.Emoticon.loadRaw(o)
        # Invalidate any properties depending on emoticons.
        App.incrementProperty('emoticonsVersion')

        obj = json.find (o) -> o.object_type == 'account'
        throw new Error("Expected to find account in checkin result but didn't") unless obj?
        account = App.Account.loadRaw(obj)

        objs = json.filter (o) -> o.object_type == 'user_preferences'
        prefs = objs.map (o) -> App.Preferences.loadRaw(o)

        userAttrs = json.find (o) -> o.object_type == 'user'
        throw new Error("Expected to find user in checkin result but didn't") unless userAttrs?
        user = App.User.loadRaw(userAttrs)

        user.set('_account', account)

        return user

  login: (data) ->
    @ajax(@buildURL('/login'), 'POST', data: data)

  logout: ->
    @ajax(@buildURL('/logout'), 'POST', {})

  createUser: (data) ->
    @ajax(@buildURL('/users/create'), 'POST', data: data)

  updateCurrentUser: (data) ->
    @ajax(@buildURL('/users/update'), 'POST', data: data)

  updateCurrentUserStatus: (newStatus, newStatusText = null) ->
    user = App.get('currentUser')

    if user.arePropertiesLocked('status', 'statusText')
      Ember.Logger.warn "I can't change the status or status text of a user when I'm still waiting for a response from the server."
      return

    data =
      status: newStatus
      status_text: newStatusText
    oldStatus = user.get('status')
    oldStatusText = user.get('statusText')
    url = @buildURL('/users/update')
    user.withLockedPropertyTransaction url, 'POST', { data: data }, ['status', 'statusText'], =>
      user.setProperties(status: newStatus, statusText: newStatusText)
    , =>
      user.setProperties(status: oldStatus, statusText: oldStatusText)

  updateCurrentUserStatusText: (newStatusText) ->
    user = App.get('currentUser')

    if user.isPropertyLocked('statusText')
      Ember.Logger.warn "I can't change the status text of a user when I'm still waiting for a response from the server."
      return

    data =
      status_text: newStatusText
    oldStatusText = user.get('statusText')
    url = @buildURL('/users/update')
    user.withLockedPropertyTransaction url, 'POST', { data: data }, 'statusText', =>
      user.set('statusText', newStatusText)
    , =>
      user.set('statusText', oldStatusText)

  joinGroup: (joinCode) ->
    data =
      limit: App.Group.initialFetchLimit
    @ajax(@buildURL("/groups/join/#{joinCode}"), 'POST', data: data)
    .then (json) =>
      if ! json? || json.error?
        throw new Error(App.userMessageFromError(json))
      # Load everything from the response.
      group = App.Group.loadSingle(json)
      if group?
        group.set('isDeleted', false)
        group.subscribeToMessages()
        # TODO: This is techincally a race condition where messages could
        # come in between downloading them all and subscribing.
        #
        # .then =>
        #   # Fetch all messages after subscribing.
        #   group.reload()
      return group
    , (xhr) =>
      throw new Error(App.userMessageFromError(xhr))
    .catch App.rejectionHandler

  updateLastSeenRank: (conversation, lastSeenRank) ->
    data =
      last_seen_rank: lastSeenRank
    # Fire and forget.
    @ajax(conversation.updateUrl(), 'POST', data: data)

  fetchAllConversations: ->
    api = App.get('api')
    api.ajax(api.buildURL('/conversations'), 'GET', data: {})
    .then (json) =>
      if json.error?
        throw json

      instances = App.loadAll(json)
      return instances.filter (o) -> o.get('actsLikeConversation')

  fetchContacts: (data) ->
    @ajax(@buildURL('/contacts'), 'GET', data: data)

  addUserContacts: (users) ->
    users = Ember.makeArray(users)
    data =
      user_ids: users.mapProperty('id').join(',')
    @ajax(@buildURL('/contacts/add'), 'POST', data: data)

  removeUserContacts: (users) ->
    users = Ember.makeArray(users)
    data =
      user_ids: users.mapProperty('id').join(',')
    @ajax(@buildURL('/contacts/remove'), 'POST', data: data)

  addEmailContacts: (data) ->
    data.emails = data.emails.join(',') if Ember.isArray(data.emails)
    @ajax(@buildURL('/contacts/add'), 'POST', data: data)

  updatePreferences: (data) ->
    @ajax(@buildURL('/preferences/update'), 'POST', data: data)

  sendPasswordResetEmail: (login) ->
    data =
      login: login
    @ajax(@buildURL('/password/reset_email'), 'POST', data: data)

  resetPassword: (token, newPassword) ->
    data =
      new_password: newPassword
    # If we're logged in, don't use that token.
    _.extend data, @defaultParams()
    delete data.token

    @ajax(@buildURL("/password/reset/#{token}"), 'POST', data: data, _appUseDefaults: false)

  deserializeUnixTimestamp: (serialized) ->
    newSerialized = if Ember.typeOf(serialized) == 'number'
      serialized * 1000
    else
      serialized

    if Ember.typeOf(newSerialized) in ['number', 'string']
      new Date(newSerialized)
    else
      null
