window.App = App = Ember.Application.create
  LOG_TRANSITIONS: true

  isLoggingIn: false

  token: null

  currentUser: null

  fayeClient: null

  continueTransition: null

  hasNotificationPermission: false

  emoticonsVersion: null

  # Whether the app/window has focus.
  hasFocus: true

  currentlyViewingRoom: null

  ready: ->
    # API implementation.
    api = App.RemoteApi.create()
    @set('api', api)

    @set('fayeClient', App.Faye.createClient())

    token = window.localStorage['token']
    if token?
      # We have a token.  Fetch the current user so that we can be fully logged
      # in.
      App.set('isLoggingIn', true)
      api.fetchCurrentUser(token)
      .then (json) =>
        App.set('isLoggingIn', false)

        if Ember.isArray(json)
          userJson = json.find (o) -> o.object_type == 'user'
          user = App.User.loadRaw(userJson)
          App.login(token, user)
          appController = App.__container__.lookup('controller:application')
          if appController.get('currentPath') == 'login'
            # We're currently on the login page, so automatically transition to
            # somewhere more interesting.
            transition = App.get('continueTransition')
            if transition?
              transition.retry()
              App.set('continueTransition', null)
            else
              App.__container__.lookup('router:main').transitionTo('rooms.index')
      , (e) =>
        App.set('isLoggingIn', false)
        if e? && /invalid token/i.test(e.responseJSON?.error?.message ? '')
          Ember.Logger.log "Invalid token; logging out"
          window.localStorage.removeItem('token')

  isLoggedIn: -> @get('currentUser')?

  login: (token, user) ->
    @set('currentUser', user)
    @set('token', token)
    window.localStorage['token'] = token

    # Fetch emoticons after logging in.
    App.Emoticon.fetchAll()

  # Note: due to browser restrictions, the actual infobar to ask the user to
  # enable notifications can only be displayed as the result of a click or other
  # user event.
  requestNotificationPermission: ->
    # Request permission to show desktop notifications.
    permissionLevel = window.notify.permissionLevel()
    @updateNotificationPermissionState(permissionLevel)
    if permissionLevel == window.notify.PERMISSION_DEFAULT
      Ember.Logger.log "Requesting permission for desktop notifications"
      window.notify.requestPermission =>
        Ember.run @, ->
          @updateNotificationPermissionState()

  updateNotificationPermissionState: (permissionLevel = null) ->
    permissionLevel ?= window.notify.permissionLevel()
    App.set('hasNotificationPermission', permissionLevel == window.notify.PERMISSION_GRANTED)

  loadAll: (json) ->
    instances = for attrs in Ember.makeArray(json)
      type = @classFromRawObject(attrs)
      if type?
        type.loadRaw(attrs)

    instances.compact()

  classFromRawObject: (obj) ->
    switch obj.object_type
      when 'group'
        App.Group
      when 'message'
        App.Message
      when 'user'
        App.User


if Modernizr.history
  # Browser supports pushState.
  App.Router.reopen
    location: 'history'


App.Router.map ->

  @route 'login', path: '/login'

  @resource 'rooms', path: '/', ->
    @route 'room', path: '/rooms/:group_id'
