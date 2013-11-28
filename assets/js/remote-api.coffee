App.RemoteApi = Ember.Object.extend

  namespace: 'api'

  defaultParams: ->
    data = {}

    token = App.get('token')
    data.token = token if token?

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
      token = App.get('token')
      if token?
        hash.data ?= {}
        _.extend hash.data, @defaultParams()

      if hash.data && type != 'GET'
        hash.contentType ?= 'application/json; charset=utf-8'
        hash.data = JSON.stringify(hash.data) if hash.processData != false

      hash.success = (json) ->
        Ember.run(null, resolve, json)

      hash.error = (jqXHR, textStatus, errorThrown) ->
        Ember.run(null, reject, jqXHR)

      Ember.$.ajax(hash)

  buildURL: (url) ->
    if url? && url[0] != '/'
      url = '/' + url

    url = [@get('namespace'), url].compact().join('')
    url = '/' + url if url[0] != '/'

    url = App.webServerUrl(url)

    url

  checkin: (data) ->
    api = App.get('api')
    api.ajax(api.buildURL('/checkin'), 'POST', data: data)
    .then (json) =>
      if ! json? || json.error?
        throw json
      else
        json = Ember.makeArray(json)

        # Get version.
        meta = json.find (o) -> o.object_type == 'meta'
        version = meta.emoticons?.version
        App.set('emoticonsVersion', version) if version?

        objs = json.filter (o) -> o.object_type == 'emoticon'
        emoticons = objs.map (o) -> App.Emoticon.loadRaw(o)

        obj = json.find (o) -> o.object_type == 'account'
        throw new Error("Expected to find account in checkin result but didn't") unless obj?
        account = App.Account.loadRaw(obj)

        objs = json.filter (o) -> o.object_type == 'preferences'
        prefs = objs.map (o) -> App.Preferences.loadRaw(o)

        userAttrs = json.find (o) -> o.object_type == 'user'
        throw new Error("Expected to find user in checkin result but didn't") unless userAttrs?
        user = App.User.loadRaw(userAttrs)

        user.set('_account', account)

        return user

  login: (email, password) ->
    data =
      email: email
      password: password
    @ajax(@buildURL('/login'), 'POST', data: data)

  createUser: (email, password, name) ->
    data =
      email: email
      password: password
      name: name
    @ajax(@buildURL('/users/create'), 'POST', data: data)

  updateCurrentUser: (data) ->
    @ajax(@buildURL('/users/update'), 'POST', data: data)

  updateCurrentUserStatus: (newStatus) ->
    user = App.get('currentUser')

    if user.isPropertyLocked('status')
      Ember.Logger.warn "I can't change the status of a user when I'm still waiting for a response from the server."
      return

    data =
      status: newStatus
    oldStatus = user.get('status')
    url = @buildURL('/users/update')
    user.withLockedPropertyTransaction url, 'POST', { data: data }, 'status', =>
      user.set('status', newStatus)
    , =>
      user.set('status', oldStatus)

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
    @ajax(@buildURL("/groups/join/#{joinCode}"), 'POST', {})

  fetchAllConversations: ->
    api = App.get('api')
    api.ajax(api.buildURL('/conversations'), 'GET', data: {})
    .then (json) =>
      if json.error?
        throw json

      instances = App.loadAll(json)
      return instances.filter (o) -> o.get('actsLikeConversation')

  updatePreferences: (data) ->
    @ajax(@buildURL('/preferences/update'), 'POST', data: data)

  sendPasswordResetEmail: (login) ->
    data =
      login: login
    @ajax(@buildURL('/password/reset_email'), 'POST', data: data)

  resetPassword: (token, newPassword) ->
    data =
      new_password: newPassword
    @ajax(@buildURL("/password/reset/#{token}"), 'POST', data: data)

  deserializeUnixTimestamp: (serialized) ->
    newSerialized = if Ember.typeOf(serialized) == 'number'
      serialized * 1000
    else
      serialized

    if Ember.typeOf(newSerialized) in ['number', 'string']
      new Date(newSerialized)
    else
      null
