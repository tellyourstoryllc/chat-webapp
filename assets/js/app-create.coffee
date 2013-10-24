window.App = App = Ember.Application.create
  LOG_TRANSITIONS: true

  # Default title displayed in the window/tab's titlebar.
  title: 'Chat App'

  isLoggingIn: false

  token: null

  currentUser: null

  fayeClient: null

  isFayeClientConnected: false

  continueTransition: null

  hasNotificationPermission: false

  emoticonsVersion: null

  # Whether the app/window has focus.
  hasFocus: true

  currentlyViewingRoom: null

  # The current `App.RoomsRoomView` instance.
  currentRoomView: null

  # Date instance used to track idle time.
  lastActiveAt: null

  # Calculated number of seconds that the current user has been idle on this
  # device.
  idleForSeconds: 0

  # The number of minutes of inactivity after which the client is considered
  # idle on this device.
  showIdleAfterMinutes: 5

  # Boolean whether the current user is idle on this device.
  isIdle: false

  # Messages that should flash in the browser window/tab's titlebar.  General
  # use is to unshift an object with an id and a title.
  pageTitlesToFlash: []

  ready: ->
    # API implementation.
    api = App.RemoteApi.create()
    @set('api', api)

    @set('lastActiveAt', new Date())

    # Setup Faye client.
    fayeClient = App.Faye.createClient()
    @set('fayeClient', fayeClient)
    _.bindAll(@, 'onFayeTransportUp', 'onFayeTransportDown')
    fayeClient.on 'transport:up', @onFayeTransportUp
    fayeClient.on 'transport:down', @onFayeTransportDown

    token = window.localStorage['token']
    if token?
      # We have a token.  Fetch the current user so that we can be fully logged
      # in.
      App.set('isLoggingIn', true)
      api.updateCurrentUser(_.extend(@userStatusParams(), token: token))
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
              App._getRouter().transitionTo('rooms.index')
      , (e) =>
        App.set('isLoggingIn', false)
        if e? && /invalid token/i.test(e.responseJSON?.error?.message ? '')
          Ember.Logger.log "Invalid token; logging out"
          window.localStorage.removeItem('token')

  onFayeTransportUp: ->
    Ember.run @, ->
      @set('isFayeClientConnected', true)
      @updateStatusAfterConnect()

  onFayeTransportDown: ->
    Ember.run @, ->
      @set('isFayeClientConnected', false)

  # Returns the router.  You should only call this as a last resort.
  _getRouter: ->
    @__container__.lookup('router:main')

  isLoggedIn: -> @get('currentUser')?

  login: (token, user) ->
    @set('currentUser', user)
    @set('token', token)
    window.localStorage['token'] = token

    # Fetch emoticons after logging in.
    App.Emoticon.fetchAll()

    @updateStatusAfterConnect() if @get('isFayeClientConnected')

  updateStatusAfterConnect: ->
    return unless @isLoggedIn()
    App.get('api').updateCurrentUser(@userStatusParams())

  userStatusParams: ->
    # TODO: save status in memory if user sets it to away or something other
    # than available and return that.  Also track idle time.
    status: 'available'
    status_text: null

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

  doesBrowserSupportAjaxFileUpload: ->
    !! (Modernizr.fileinput && window.FormData)

  onMessageImageLoad: (groupId) ->
    Ember.run @, ->
      group = App.Group.lookup(groupId)
      return unless group?

      # Make sure we're still viewing the same room.
      if App.get('currentlyViewingRoom') == group
        view = App.get('currentRoomView')
        view?.didLoadMessageImage()

  loadAll: (json, options = {}) ->
    instances = for attrs in Ember.makeArray(json)
      type = @classFromRawObject(attrs)
      if type?
        type.loadRaw(attrs)

    instances = instances.compact()

    if options.loadSingleGroup
      group = instances.find (o) -> o instanceof App.Group
      group.didLoadMembers()
      if Ember.isEmpty(group.get('messages'))
        group.set('messages', instances.filter (o) -> o instanceof App.Message)

    instances


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

  @route 'join', path: '/join/:join_code'

  @route 'login', path: '/login'
  @route 'logout', path: '/logout'
  @route 'signup', path: '/signup'

  @resource 'rooms', path: '/rooms', ->
    @route 'room', path: '/:group_id'

  @route 'index', path: '/'
