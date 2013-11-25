window.App = App = Ember.Application.create
  LOG_TRANSITIONS: true

  # Default title displayed in the window/tab's titlebar.
  title: 'SkyMob'

  # Object that mixes in `Ember.Evented` and receives application events.
  #
  # List of events:
  # - didLogIn
  eventTarget: null

  isLoggingIn: false

  token: null

  currentUser: null

  _isLoggedIn: false

  fayeClient: null

  isFayeClientConnected: false

  continueTransition: null

  hasNotificationPermission: false

  emoticonsVersion: null

  # Whether the app/window has focus.
  hasFocus: true

  # The current `App.Group` instance.
  currentlyViewingRoom: null

  # Date instance used to track idle time.
  lastActiveAt: null

  # Calculated number of seconds that the current user has been idle on this
  # device.
  idleForSeconds: 0

  # Boolean whether the current user is idle on this device.
  isIdle: false

  # Messages that should flash in the browser window/tab's titlebar.  General
  # use is to unshift an object with an id and a title.
  pageTitlesToFlash: []

  # User preferences like notification settings.
  preferences: null

  # The faye subscription to the current user's channel.
  userChannelSubscription: null

  # True when the `userChannelSubscription` is fully subscribed.
  isSubscribedToUserChannel: false

  # The `App.RoomsContainerComponent` currently being displayed.
  roomsContainerView: null

  # Ember.Map whose keys are `App.Group` instances, and values are
  # `App.RoomMessagesView` instances.
  roomMessagesViews: null

  defaultErrorMessage: "There was an unknown error.  Please try again."

  ready: ->
    Ember.onerror = (e) ->
      # TODO: Send error to server.

      Ember.Logger.error(e.message, e, e?.stack ? e?.stacktrace)

      undefined

    if ! Modernizr.history
      # Browser doesn't support changing the URL without reloading the page.  If
      # we have a hash, we were probably on IE9 or below and refreshed the page
      # or were redirected.  So preserve it.  Otherwise, use the URL path.
      if Ember.isEmpty(window.location.hash)
        # Copy the URL path to hash.
        @_getRouter().location.setURL(window.location.pathname)

    @set('eventTarget', Ember.Object.extend(Ember.Evented).create())

    # API implementation.
    api = App.RemoteApi.create()
    @set('api', api)

    @set('lastActiveAt', new Date())

    @set('roomMessagesViews', Ember.Map.create())

    # Setup Faye client.
    fayeClient = App.Faye.createClient()
    @set('fayeClient', fayeClient)
    _.bindAll(@, 'onFayeConnect', 'onFayeTransportUp', 'onFayeTransportDown')
    fayeClient.on 'app:connect', @onFayeConnect
    fayeClient.on 'transport:up', @onFayeTransportUp
    fayeClient.on 'transport:down', @onFayeTransportDown

    token = window.localStorage['token']
    if token?
      # We have a token.  Fetch the current user so that we can be fully logged
      # in.
      App.set('isLoggingIn', true)
      api.checkin(token: token)
      .then (user) =>
        App.set('isLoggingIn', false)

        App.login(token, user)

        @whenLoggedIn =>
          # Automatically transition to somewhere more interesting.
          transition = App.get('continueTransition')
          if transition?
            transition.retry()
            App.set('continueTransition', null)
          else
            appController = App.__container__.lookup('controller:application')
            # We're currently on the login or home page, so go to the default
            # place.
            if appController.get('currentPath') in ['index', 'login']
              App._getRouter().transitionTo('rooms.index')
      , (e) =>
        App.set('isLoggingIn', false)
        if e? && /invalid token/i.test(e.responseJSON?.error?.message ? '')
          Ember.Logger.log "Invalid token; logging out"
          window.localStorage.removeItem('token')
      .fail App.rejectionHandler

  # Common promise rejection handler.  Use this as the final handler whenever
  # you create a promise so that errors don't get swallowed.  For example:
  #
  #     somethingAsync()
  #     .then (result) ->
  #       coolStuff(result) # This could accidentally throw an exception.
  #     .fail App.rejectionHandler
  rejectionHandler: (e) ->
    Ember.Logger.error(e, e?.message, e?.stack ? e?.stacktrace)
    throw e

  onFayeConnect: ->
    Ember.run @, ->
      Ember.Logger.log "faye app:connect", new Date()
      @set('isFayeClientConnected', true)
      @updateStatusAfterConnect()
      @get('eventTarget').trigger('didConnect')
      return undefined

  onFayeTransportUp: ->
    Ember.run @, ->
      Ember.Logger.log "faye transport:up", new Date()
      return undefined

  onFayeTransportDown: ->
    Ember.run @, ->
      Ember.Logger.log "faye transport:down", new Date()
      return undefined

  # Returns the router.  You should only call this as a last resort.
  _getRouter: ->
    @__container__.lookup('router:main')

  # Returns the view instance from a given HTML element id.  You should only
  # call this as a last resort.
  _viewFromElement: (idOrJqueryElement) ->
    id = if Ember.typeOf(idOrJqueryElement) == 'string'
      idOrJqueryElement
    else
      idOrJqueryElement.attr('id')
    Ember.View.views[id]

  isLoggedIn: -> @get('_isLoggedIn')

  login: (token, user) ->
    @set('currentUser', user)
    @set('token', token)
    window.localStorage['token'] = token

    if App.Preferences.all().length > 0
      @didCheckIn()
    else
      # In the case of logging in for the first time, we haven't called checkin
      # yet.
      App.get('api').checkin(token: token).then (user) =>
        @didCheckIn()
      .fail App.rejectionHandler

  # This is triggered after logging in and checking in.
  didCheckIn: ->
    # Setup preferences.
    prefs = App.Preferences.all()[0]
    clientPrefs = prefs.get('clientWeb')
    for key, defaultVal of App.Preferences.clientPrefsDefaults
      val = undefined
      # Prefer localStorage value.
      strVal = window.localStorage.getItem(key)
      if strVal?
        val ?= App.Preferences.coerceValueFromStorage(key, strVal)
      val ?= clientPrefs.get(key)
      val ?= defaultVal
      clientPrefs.set(key, val)
    @set('preferences', prefs)

    user = @get('currentUser')

    # Listen for status updates from other users, echoes of our own status, and
    # one to one messages.
    subscription = @get('fayeClient').subscribe "/users/#{user.get('id')}", (json) =>
      Ember.run @, ->
        Ember.Logger.log "received user packet", json
        if ! json? || json.error?
          return

        if json.object_type == 'user'
          # We received a user status update.
          App.loadAll(json)
        else if json.object_type == 'message' && json.one_to_one_id?
          # We received a new 1-1 message.
          App.OneToOne.find(json.one_to_one_id)
          .then (oneToOne) =>
            oneToOne.didReceiveUpdateFromFaye(json)
        else if json.object_type == 'one_to_one'
          # We received an update to a OneToOne.
          oneToOne = App.OneToOne.lookup(oneToOneJson.id)
          if oneToOne?
            # If we've loaded this OneToOne before, notify the existing instance
            # so that it can handle changes.
            oneToOne.didReceiveUpdateFromFaye(json)
          else
            # This is a OneToOne we've never seen before, so just load it.
            App.loadAll(json)
        else if json.object_type == 'preferences'
          # Don't synchronize the client preferences; only server preferences.
          delete json.client_web
          App.loadAll(json)
        else if json.object_type == 'account'
          # We received an account update for things like 1-1 wallpaper.
          instances = App.loadAll(json)
          account = instances.find (o) -> o instanceof App.Account
          user = App.User.lookup(json.user_id)
          if user? && account?
            user.set('_account', account)
        return undefined
    @set('userChannelSubscription', subscription)

    subscription.then =>
      @set('isSubscribedToUserChannel', true)
      # Update our own status after we ensure that we're listening for status
      # updates.
      @updateStatusAfterConnect() if @get('isFayeClientConnected')

    @set('_isLoggedIn', true)

    # Trigger didLogIn event after we've set up the token and logged in state.
    @get('eventTarget').trigger('didLogIn')

  # Runs callback asynchronously.  If condition is true, runs in next iteration
  # of the run loop.  Otherwise, it runs when the event triggers.
  when: (condition, eventTarget, eventName, target, method) ->
    if condition
      Ember.run.next target, method
    else
      eventTarget.one eventName, target, method

  # Runs callback asynchronously after logging in.  ***You should only call this
  # when you know the user is about to log in.***
  whenLoggedIn: (target, method) ->
    @when @isLoggedIn(), @get('eventTarget'), 'didLogIn', arguments...

  updateStatusAfterConnect: ->
    @publishClientStatus()

  publishClientStatus: ->
    return unless @isLoggedIn() && @get('isSubscribedToUserChannel')
    data = if App.get('isIdle')
      status: 'idle'
      idle_duration: App.get('idleForSeconds')
    else
      status: 'active'
    data.client_type = 'web'
    App.get('fayeClient').publish('/clients/update', data)

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

  onMessageImageLoad: (groupId, element, isEmoticon) ->
    Ember.run @, ->
      group = App.Group.lookup(groupId)
      return unless group?

      # Make sure we're still viewing the same room.
      if App.get('currentlyViewingRoom') == group
        view = App.get('roomMessagesViews').get(group)
        view?.didLoadMessageImage(element, isEmoticon)

  loadAllWithMetaData: (json) ->
    descs = for attrs in Ember.makeArray(json)
      type = @classFromRawObject(attrs)
      if type?
        if type.loadRawWithMetaData
          type.loadRawWithMetaData(attrs)
        else
          [type.loadRaw(attrs), null]

    descs.compact()

  loadAll: (json) ->
    @allInstancesFromLoadMetaData(@loadAllWithMetaData(arguments...))

  allInstancesFromLoadMetaData: (loadMetas, filterFn = null) ->
    loadMetas = loadMetas.filter(filterFn) if filterFn?
    loadMetas.map ([inst]) -> inst

  newInstancesFromLoadMetaData: (loadMetas, filterFn = null) ->
    loadMetas.filter ([inst, isNew]) ->
      isNew? && isNew && (! filterFn? || filterFn(inst))
    .map ([inst]) -> inst

  existingInstancesFromLoadMetaData: (loadMetas, filterFn = null) ->
    loadMetas.filter ([inst, isNew]) ->
      isNew? && ! isNew && (! filterFn? || filterFn(inst))
    .map ([inst]) -> inst

  classFromRawObject: (obj) ->
    switch obj.object_type
      when 'account'
        App.Account
      when 'emoticon'
        App.Emoticon
      when 'group'
        App.Group
      when 'message'
        App.Message
      when 'one_to_one'
        App.OneToOne
      when 'preferences'
        App.Preferences
      when 'user'
        App.User

  loadConfig: (key, scope = null) ->
    value = undefined
    if scope?
      value ?= window.localStorage.getItem("#{key}.#{scope}")
    value ?= window.localStorage.getItem("#{key}")

    value

  userMessageFromError: (xhrOrError) ->
    if xhrOrError?
      msg = xhrOrError.responseJSON?.error?.message
      msg ?= xhrOrError.error?.message
    msg ?= App.defaultErrorMessage

    msg


if Modernizr.history
  # Browser supports pushState.
  App.Router.reopen
    location: 'history'


App.Router.map ->

  @route 'join', path: '/join/:join_code'

  @route 'login', path: '/login'
  @route 'logout', path: '/logout'
  @route 'signup', path: '/signup'

  @route 'forgot-password', path: '/forgot-password'
  @route 'password-reset', path: '/password/reset/:token'

  @resource 'rooms', path: '/rooms', ->
    @route 'room', path: '/:room_id'

  @route 'index', path: '/'
