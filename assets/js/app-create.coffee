window.App = App = Ember.Application.create

  # Default title displayed in the window/tab's titlebar.
  title: 'skymob'

  # Set to true to enable more verbose logging to the console.
  useDebugLogging: false

  # Query string that is appended to tracked URL for analytics.
  pendingQueryString: null

  # Object that mixes in `Ember.Evented` and receives application events.
  #
  # List of events:
  # - didLogIn
  # - didLoadFacebook
  eventTarget: null

  isLoggingIn: false

  token: null

  currentUser: null

  currentUserContacts: null

  _isLoggedIn: false

  fayeClient: null

  isFayeClientConnected: false

  isHeartbeatActive: true

  # Ember route transition to continue to after logging in.
  continueTransition: null

  # Args to Ember's `Route::transitionTo()` to continue to after logging in.
  # Needs to be an args array since `undefined` is a valid context.
  continueTransitionArgs: null

  continueToMostRecentRoom: false

  # Set to a Group's join code to display on the home page.
  joinCodeToShow: null
  roomKeyTextToShow: null

  # Set to true to show the room key form (and not signup button) in the
  # application navbar.
  showRoomKeyForm: false

  # Temporary email address to pass between pages in the UI.
  emailAddress: null

  # Set to a Group instance to auto join it and go to it after the user logs in.
  autoJoinAfterLoggingIn: null

  isRequestingNotificationPermission: false
  hasNotificationPermission: false

  emoticonsVersion: 0

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

  # True when the FB external JS library has been loaded.
  isFacebookLoaded: false

  # True if we're running inside MacGap
  isMacGap: false

  # Index (i.e. home page) does some crazy handling of the navbar, so the
  # ApplicationRoute needs access to it.
  indexView: null

  ready: ->
    Ember.onerror = (e) ->
      # TODO: Send error to server.

      Ember.Logger.error(e.message, e, e?.stack ? e?.stacktrace)

      undefined

    # Load debug logging setting from localStorage to help debug page load.
    useDebugLogging = window.localStorage.getItem('useDebugLogging')
    if useDebugLogging in ['1', 'true']
      @set('useDebugLogging', true)

    # Ember blows away the query string, so we extract it now.
    queryString = window.location.search
    if ! Ember.isEmpty(queryString)
      # Parse params.
      parts = (queryString ? '').replace(/^\?/, '').split('&')
      pairs = parts.map (pair) -> pair.split('=')
      # Extract invite_token.  Don't let analytics track this.
      inviteTokenIndex = null
      for pair, i in pairs
        if pair[0] == 'invite_token'
          inviteTokenIndex = i
          break
      if inviteTokenIndex? && (val = pairs[inviteTokenIndex][1])?
        # Convert pluses to spaces and then decode.
        inviteToken = decodeURIComponent(val.replace(/\+/g, ' '))
        # Change to fake token so it doesn't get sent to analytics.
        pairs[inviteTokenIndex][1] = 'XXX'
      # Convert back to query string.
      if ! Ember.isEmpty(pairs)
        # Never decoded, so don't need to encode.
        queryString = App.Util.arrayToQueryString(pairs, false)
    # Our analytics tracking uses this.
    App.set('pendingQueryString', queryString)

    if ! Modernizr.history
      # Browser doesn't support changing the URL without reloading the page.  If
      # we have a hash, we were probably on IE9 or below and refreshed the page
      # or were redirected.  So preserve it.  Otherwise, use the URL path.
      if Ember.isEmpty(window.location.hash)
        # Copy the URL path to hash.
        @_getRouter().location.setURL(window.location.pathname)

    # Show the environment in the browser titlebar.
    if AppConfig.env in ['development', 'staging', 'testing']
      title = "#{App.get('title')} - #{AppConfig.env}"
      App.set('title', title)
      $(document).attr('title', "#{title}")

    # Whether we're running inside MacGap.
    @set('isMacGap', AppConfig.isMacGap)

    @set('eventTarget', Ember.Object.extend(Ember.Evented).create())

    # API implementation.
    api = App.RemoteApi.create()
    @set('api', api)

    @set('lastActiveAt', new Date())

    @set('roomMessagesViews', Ember.Map.create())

    # Setup Faye client.
    try
      fayeClient = App.Faye.createClient()
    catch e
      if /Faye/.test(e?.message)
        Ember.Logger.error e, e.stack ? e.stacktrace
        App.set 'blowUpWithMessage',
          title: "500 Internal Server Error"
          message: "There was an error connecting to the messaging server."
          shouldRetry: true
      else
        throw e
    @set('fayeClient', fayeClient)
    _.bindAll(@, 'onFayeConnect', 'onFayeTransportUp', 'onFayeTransportDown')
    if fayeClient?
      fayeClient.on 'app:connect', @onFayeConnect
      fayeClient.on 'transport:up', @onFayeTransportUp
      fayeClient.on 'transport:down', @onFayeTransportDown

    token = window.localStorage['token']
    if token?
      # We have a token.  Fetch the current user so that we can be fully logged
      # in.
      @logInFromToken(token)
    else if inviteToken?
      @logInFromInviteToken(inviteToken)
    else
      # No token.  Not logged in.

      # Use localStorage or default preferences.  Not kept in our local store so
      # that when we do fetch Preferences, those are used.
      App.usePreferences(App.Preferences.create())

    # Setup copying to clipboard.  Versioning the URL to prevent caching issues.
    ZeroClipboard.setDefaults(moviePath: '/ZeroClipboard-v1.2.3.swf', hoverClass: 'hover')

    # If we're already running in the Mac app, we don't need it.
    App.set('needsMacApp', ! macgap? && App.doesSystemSupportMacApp())

  logInFromToken: (token) ->
    App.set('isLoggingIn', true)
    App.get('api').checkin(token: token)
    .always =>
      App.set('isLoggingIn', false)
    .then (user) =>
      App.login(token, user)

      @whenLoggedIn =>
        @continueAfterLoggingIn()
    .catch App.rejectionHandler

  logInFromInviteToken: (inviteToken) ->
    App.set('isLoggingIn', true)

    blowUpWithDefaultMessage = ->
      # TODO: This doesn't actually do anything.  Need to change how this is
      # rendered.
      #
      # App.set 'blowUpWithMessage',
      #   title: "Sorry, there was a problem with that invite link."
      #   htmlMessage: "Go To <a href='/login'>Login</a>."

    App.get('api').login(invite_token: inviteToken)
    .always =>
      App.set('isLoggingIn', false)
    .then (json) =>
      if ! json? || json.error?
        blowUpWithDefaultMessage()
        throw json

      json = Ember.makeArray(json)

      userJson = json.find (o) -> o.object_type == 'user'
      if userJson?.token?
        token = userJson.token
        delete userJson.token

      user = App.User.loadRaw(userJson)
      if token?
        App.login(token, user)

        @whenLoggedIn =>
          @continueAfterLoggingIn()
      else
        blowUpWithDefaultMessage()

    , (xhr) =>
      if xhr.status == 401
        # TODO: Show this error message.
        App.set 'blowUpWithMessage',
          title: "Sorry, you don't have permission to view that."
          htmlMessage: "Go To <a href='/login'>Login</a>."
      else
        blowUpWithDefaultMessage()
    .catch App.rejectionHandler

  # Transition to somewhere more interesting.
  continueAfterLoggingIn: ->
    transition = App.get('continueTransition')
    if transition?
      App.set('continueTransition', null)
      newTrans = transition.retry()
      # Replace /login with this new URL.
      newTrans.method('replace')
    else
      appController = App.__container__.lookup('controller:application')
      # We're currently on the login or home page, so go to the default
      # place.
      if appController.get('currentPath') in ['index', 'login']
        # Go to most recent room if we have one.
        App.set('continueToMostRecentRoom', true)

        App._getRouter().replaceWith('rooms.index')

  # Common promise rejection handler.  Use this as the final handler whenever
  # you create a promise so that errors don't get swallowed.  For example:
  #
  #     somethingAsync()
  #     .then (result) ->
  #       coolStuff(result) # This could accidentally throw an exception.
  #     .catch App.rejectionHandler
  rejectionHandler: (e) ->
    Ember.Logger.error(e, e?.message, e?.stack ? e?.stacktrace)
    throw e

  onFayeConnect: ->
    Ember.run @, ->
      Ember.Logger.log "faye app:connect", new Date() if App.get('useDebugLogging')
      @set('isFayeClientConnected', true)
      @updateStatusAfterConnect()
      @get('eventTarget').trigger('didConnect')
      return undefined

  onFayeTransportUp: ->
    Ember.run @, ->
      Ember.Logger.log "faye transport:up", new Date() if App.get('useDebugLogging')
      return undefined

  onFayeTransportDown: ->
    Ember.run @, ->
      Ember.Logger.log "faye transport:down", new Date() if App.get('useDebugLogging')
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
      .catch App.rejectionHandler

  # This is triggered after logging in and checking in.
  didCheckIn: ->
    # Setup preferences.
    @usePreferences(App.Preferences.all()[0])

    user = @get('currentUser')

    # Listen for status updates from other users, echoes of our own status, and
    # one to one messages.
    subscription = @get('fayeClient').subscribe "/users/#{user.get('id')}", (json) =>
      Ember.run @, ->
        Ember.Logger.log "received user packet", json if App.get('useDebugLogging')
        if ! json? || json.error?
          return

        if json.object_type == 'user'
          # We received a user status update.
          App.loadAll(json)
        else if json.object_type == 'message' && json.one_to_one_id?
          # We received a new 1-1 message.
          oneToOne = App.OneToOne.lookup(json.one_to_one_id)
          if oneToOne?
            oneToOne.didReceiveUpdateFromFaye(json)
          else
            # This is the first message in a 1-1 we've never seen before.  We
            # need to force notifying in the UI.
            App.OneToOne.fetchAndLoadSingle(json.one_to_one_id)
            .then (oneToOne) =>
              oneToOne.didReceiveUpdateFromFaye(json, forceNotify: true)
        else if json.object_type == 'group'
          # We received a Group.
          group = App.Group.lookup(json.id)
          if group?
            # If we've loaded this Group before, notify the existing instance so
            # that it can handle changes.
            group.didReceiveUpdateFromFaye(json)
          else
            # This is a Group we've never seen before, so load it and subscribe.
            instances = App.loadAll(json)
            group = instances.find (o) -> o instanceof App.Group
            group.subscribeToMessages().then =>
              group.reload()
        else if json.object_type == 'one_to_one'
          # We received an update to a OneToOne.
          oneToOne = App.OneToOne.lookup(json.id)
          if oneToOne?
            # If we've loaded this OneToOne before, notify the existing instance
            # so that it can handle changes.
            oneToOne.didReceiveUpdateFromFaye(json)
          else
            # This is a OneToOne we've never seen before, so just load it.
            App.loadAll(json)
        else if json.object_type == 'user_preferences'
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
  # of the run loop.  Otherwise, it runs when the event triggers. Set
  # `runImmediately` to true to call immediately when the condition is true,
  # instead of waiting for the next run loop.
  when: (condition, eventTarget, eventName, target, method, options = {}) ->
    if condition
      if options.runImmediately
        fn = if typeof target == 'function'
          target
        else if typeof method == 'function'
          method
        else
          target[method]
        fn.call(target)
      else
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

    # Client type.
    data.client_type = 'web'
    # Use screen dimensions to determine if it's probably a phone or tablet.
    if screen? && screen.width? && screen.height?
      minScreenDimen = Math.min(screen.width, screen.height)
      maxScreenDimen = Math.max(screen.width, screen.height)
      if minScreenDimen <= 400 || maxScreenDimen <= 480
        # If screen is 480 or smaller, we're probably on a phone no matter what.
        # iPhone 5 (4-inch display) 320x568 should fall here.
        data.client_type = 'phone'
      else if maxScreenDimen < 1024
        # If screen is less than 1024, it's probably a tablet no matter what.
        data.client_type = 'tablet'
      else if maxScreenDimen == 1024 && (Modernizr.appleios || Modernizr.android)
        # If screen is 1024, it could be a tablet or a very old desktop.
        data.client_type = 'tablet'

    App.get('fayeClient').publish('/clients/update', data)

  # After getting an updated authentication token, for example, after changing
  # the user's password, call this to begin using the new token.
  useNewAuthToken: (token) ->
    App.set('token', token)
    window.localStorage.setItem('token', token)

  # Given an `App.Preferences` instance, load defaults and set it up to actually
  # be used.
  usePreferences: (prefs) ->
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

  # Note: due to browser restrictions, the actual infobar to ask the user to
  # enable notifications can only be displayed as the result of a click or other
  # user event.
  requestNotificationPermission: ->
    # Request permission to show desktop notifications.
    permissionLevel = window.notify.permissionLevel()
    @updateNotificationPermissionState(permissionLevel)
    if permissionLevel == window.notify.PERMISSION_DEFAULT
      Ember.Logger.log "Requesting permission for desktop notifications"
      App.set('isRequestingNotificationPermission', true)
      window.notify.requestPermission =>
        Ember.run @, ->
          @updateNotificationPermissionState()

  updateNotificationPermissionState: (permissionLevel = null) ->
    permissionLevel ?= window.notify.permissionLevel()
    hasNotificationPermission = permissionLevel == window.notify.PERMISSION_GRANTED
    App.set('hasNotificationPermission', hasNotificationPermission)
    if hasNotificationPermission
      # If we have permission, the requesting process is over.
      App.set('isRequestingNotificationPermission', false)

  doesBrowserSupportAjaxFileUpload: ->
    !! (Modernizr.fileinput && window.FormData)

  doesSystemSupportMacApp: ->
    matches = /Mac OS X 10_(\d+)_/i.exec(navigator.userAgent)
    return false if ! matches?
    minor = parseInt(matches[1])

    minor? && ! _.isNaN(minor) && minor >= 8

  conversationFromId: (conversationId) ->
    if /-/.test(conversationId)
      App.OneToOne.lookup(conversationId)
    else
      App.Group.lookup(conversationId)

  onAudioEnded: (event, element) ->
    Ember.run @, ->
      $target = $(element ? event?.target)
      messageId = $target.closest('[data-message-id]').attr('data-message-id')
      message = App.Message.lookup(messageId)
      convoId = $target.closest('[data-conversation-id]').attr('data-conversation-id')
      if convoId?
        convo = App.conversationFromId(convoId)
      return unless convo? && message?

      # TODO: speed this up.  Currently linear on number of messages.
      messages = convo.get('messages')
      # Look from the end since it's more likely to be near the end.
      index = messages.lastIndexOf(message)
      return unless index >= 0
      # Find the next message with a playable audio attachment.
      for i in [index + 1 ... messages.get('length')]
        m = messages.objectAt(i)
        $audio = undefined
        if m.hasPlayableAudioAttachment?()
          guid = Ember.guidFor(m)
          $audio = $(".audio-attachment-#{guid}")
        # If we found the audio element, play it, and then we're finished.
        if $audio? && $audio.size() > 0
          $audio.get(0).play()
          break
      return undefined

  onMessageContentLoad: (conversationId, element, objectType) ->
    Ember.run @, ->
      convo = App.conversationFromId(conversationId)
      return unless convo?

      # Make sure we're still viewing the same room.
      if App.get('currentlyViewingRoom') == convo
        view = App.get('roomMessagesViews').get(convo)
        view?.contentDidChangeSize(element, objectType)

  showVideoAttachment: (event, conversationId, element, messageGuid) ->
    Ember.run @, ->
      $videoContainer = $(".video-attachment-#{messageGuid}")
      return unless $videoContainer?

      # Cancel following the link.
      event.preventDefault()

      # Hide the preview and show the video player.
      $(element).hide()
      $videoContainer.removeClass('not-displayed')
      $videoContainer.find('video').each -> @play()

      # Find the view from the room.  Notify the view so that it can scroll if
      # needed.
      convo = App.conversationFromId(conversationId)
      if convo? && App.get('currentlyViewingRoom') == convo
        view = App.get('roomMessagesViews').get(convo)
        view?.contentDidChangeSize(element, 'video-attachment')

  hideVideoAttachment: (event, conversationId, element, messageGuid) ->
    Ember.run @, ->
      event.preventDefault()
      $videoContainer = $(element).closest('.video-attachment')
      $videoContainer.addClass('not-displayed')
      $videoContainer.find('video').each -> @pause()
      $preview = $(".video-attachment-preview-#{messageGuid}")
      $preview.show()

  roomMessagesViewFromRoom: (room) ->
    App.get('roomMessagesViews').get(room)

  # Attempts to open the mobile app with the given URL.  URL should have a
  # protocol that the app understand.
  attemptToOpenMobileApp: (path) ->
    return unless Modernizr.appleios
    path = '/' + path if path[0] != '/'
    window.location = "skymob:/" + path
    # If the app isn't installed, fall back to opening the App Store.
    # window.setTimeout ->
    #   if +new Date - loadedAt < 2000
    #     # If we're still here, open the app store.
    #     window.location = "http://itunes.apple.com/app/XXXXXXX"
    # , 100

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
      when 'email'
        App.Email
      when 'emoticon'
        App.Emoticon
      when 'group'
        App.Group
      when 'message'
        App.Message
      when 'one_to_one'
        App.OneToOne
      when 'user_preferences'
        App.Preferences
      when 'user'
        App.User

  loadConfig: (key, scope = null) ->
    value = undefined
    if scope?
      value ?= window.localStorage.getItem("#{key}.#{scope}")
    value ?= window.localStorage.getItem("#{key}")

    value

  userMessageFromError: (xhrOrError, defaultMessage = null) ->
    if xhrOrError?
      msg = xhrOrError.responseJSON?.error?.message
      msg ?= xhrOrError.error?.message

      if xhrOrError.status == 422
        # Validation error.  Find the actual validation message.
        if (matches = /Validation failed:(.+)/i.exec(msg))
          newMsg = matches[1]?.trim()
          msg = newMsg if newMsg

    msg ?= defaultMessage
    msg ?= App.defaultErrorMessage

    msg

  webServerUrl: (pathOrName) ->
    if AppAssets && (path = AppAssets[pathOrName])?
      path
    else
      pathOrName

  # Returns the path part of the URL including the beginning slash if it's an
  # internal URL, i.e. within the current site (protocol, domain, port).  I
  # don't think we care about basic auth user or password.
  internalUrlPath: (url) ->
    bases = new Array(3)
    bases.push(window.location.protocol + '//' + window.location.host + '/')
    # Explicit port.
    bases.push(window.location.protocol + '//' + window.location.hostname + ':' + window.location.port + '/')
    # Implicit ports.  This may appear redundant but different browsers do
    # things differently so the above may not always work.
    if window.location.protocol == 'http:' && window.location.port == 80
      bases.push(window.location.protocol + '//' + window.location.hostname + '/')
    if window.location.protocol == 'https:' && window.location.port == 443
      bases.push(window.location.protocol + '//' + window.location.hostname + '/')

    base = bases.find((base) -> url.indexOf(base) == 0)
    return null unless base?

    # Include the beginning / in the path.
    url[base.length - 1 ..]


if Modernizr.history
  # Browser supports pushState.
  App.Router.reopen
    location: 'history'


App.Router.reopen

  # Used to prevent double tracking.
  lastPageViewUrl: null

  # Add tracking of page views with Google Analytics.
  didTransition: (infos) ->
    result = @_super(arguments...)

    Ember.run.schedule 'afterRender', =>
      location = @get('location')
      url = location.getURL()

      # If we have a query string waiting, consume it.
      pendingQueryString = App.get('pendingQueryString')
      App.set('pendingQueryString', null)
      if ! Ember.isEmpty(pendingQueryString)
        url += pendingQueryString

      if @get('lastPageViewUrl') == url
        # Skip double trigger of the same url.
        return

      @set('lastPageViewUrl', url)
      App.Analytics.trackPageView(url)

    return result


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
