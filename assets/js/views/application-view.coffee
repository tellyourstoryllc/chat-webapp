App.ApplicationView = Ember.View.extend

  fayeRefreshCheckTimer: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'focus', 'blur', 'onStorage')

  didInsertElement: ->
    $(window).focus @focus
    $(window).blur @blur
    $(window).on 'storage', @onStorage
    $('body').addClass('appleios') if Modernizr.appleios

  focus: ->
    Ember.run @, ->
      App.set('hasFocus', true)
      @hideNotifications()

  blur: ->
    Ember.run @, ->
      App.set('hasFocus', false)

  onStorage: (event) ->
    Ember.run @, ->
      storageEvent = event.originalEvent
      key = storageEvent.key
      return unless key? && App.isLoggedIn()

      if key == 'token'
        # Another window changed our login token.
        newToken = storageEvent.newValue
        if Ember.isEmpty(newToken)
          # User logged out.  We should log out too.
          @get('controller').transitionToRoute('logout')
        else
          # User got an updated token in another window.  Use it.
          App.useNewAuthToken(newToken)

      if key of App.Preferences.clientPrefsDefaults
        # Another window changed localStorage preferences.  Load them.
        clientPrefs = App.get('preferences.clientWeb')
        if clientPrefs?
          clientPrefs.set(key, App.Preferences.coerceValueFromStorage(key, storageEvent.newValue))

  loggedInChanged: (->
    @setupUi()
  ).observes('controller.isLoggedIn').on('didInsertElement')

  setupUi: ->
    if App.isLoggedIn()
      $('body').removeClass('logged-out')
    else
      $('body').addClass('logged-out')

  showAvatarsChanged: (->
    if App.get('preferences.clientWeb.showAvatars')
      $('.small-avatar').removeClass('avatars-off')
    else
      $('.small-avatar').addClass('avatars-off')
  ).observes('App.preferences.clientWeb.showAvatars')

  currentlyViewingRoomChanged: (->
    @hideNotifications()
  ).observes('App.currentlyViewingRoom')

  hideNotifications: ->
    App.get('currentlyViewingRoom')?.dismissNotifications()

  isHeartbeatActiveChanged: (->
    if App.get('isHeartbeatActive')
      @cancelFayeRefreshCheck()
    else
      @scheduleFayeRefreshCheck()
  ).observes('App.isHeartbeatActive')

  # In rare cases, faye can't reconnect.  We reload when absolutely necessary.
  fayeRefreshCheck: ->
    # When the faye heartbeat is active, all is well.
    return if App.get('isHeartbeatActive')

    api = App.get('api')
    # When the faye heartbeat isn't active, check if we're online.  If we are,
    # we may need to reload.  Wrap in a promise so we can use our standard
    # failure handler.
    #
    # Checking /health_check is actually redundant since /faye_health_check is
    # proxied through the web server to work around cross-domain non-sense.
    api.rawPromisedAjax(url: '/faye_health_check')
    .then =>
      # We can connect to the web server and faye server, so reload.
      window.location.reload(true)
    , (xhr) =>
      # If any of the promises fail, one of the servers is unreachable.  Check
      # again later.
      @scheduleFayeRefreshCheck()
    .fail App.rejectionHandler

  scheduleFayeRefreshCheck: ->
    @cancelFayeRefreshCheck()
    Ember.Logger.log new Date(), "Scheduling faye refresh check" if App.get('useDebugLogging')
    @set('fayeRefreshCheckTimer', Ember.run.later(@, 'fayeRefreshCheck', 5 * 60 * 1000))

  cancelFayeRefreshCheck: ->
    timer = @get('fayeRefreshCheckTimer')
    if timer?
      Ember.Logger.log new Date(), "Canceling faye refresh check" if App.get('useDebugLogging')
      Ember.run.cancel(timer)
