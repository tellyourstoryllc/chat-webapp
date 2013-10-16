App.RemoteApi = Ember.Object.extend

  namespace: 'api'

  # Returns RSVP.Promise.
  ajax: (url, type, hash) ->
    return new Ember.RSVP.Promise (resolve, reject) ->
      hash ||= {}
      hash.url = url
      hash.type = type
      hash.dataType = 'json'
      hash.context = App

      # Add in default params for all API requests.
      token = App.get('token')
      if token?
        hash.data ?= {}
        hash.data.token = token

      if hash.data && type != 'GET'
        hash.contentType = 'application/json; charset=utf-8'
        hash.data = JSON.stringify(hash.data)

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
    url

  login: (email, password) ->
    data =
      email: email
      password: password
    @ajax(@buildURL('/login'), 'POST', data: data)

  fetchCurrentUser: (token = null) ->
    @ajax(@buildURL('/users/update'), 'POST', data: { token: token })

  deserializeUnixTimestamp: (serialized) ->
    newSerialized = if Ember.typeOf(serialized) == 'number'
      serialized * 1000
    else
      serialized

    if Ember.typeOf(newSerialized) in ['number', 'string']
      new Date(newSerialized)
    else
      null
