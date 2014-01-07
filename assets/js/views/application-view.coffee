App.ApplicationView = Ember.View.extend

  _pageTitleFlashTimer: null
  _isShowingPageTitleFlash: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'focus', 'blur', 'onStorage')

  didInsertElement: ->
    $(window).focus @focus
    $(window).blur @blur
    $(window).on 'storage', @onStorage

  focus: ->
    Ember.run @, ->
      App.set('hasFocus', true)
      App.get('pageTitlesToFlash').clear()
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

  pageTitlesToFlashChanged: (->
    if Ember.isEmpty(App.get('pageTitlesToFlash'))
      @stopFlashingPageTitle()
    else
      @startFlashingPageTitle()
  ).observes('App.pageTitlesToFlash.@each')

  startFlashingPageTitle: ->
    timer = @get('_pageTitleFlashTimer')
    if ! timer?
      @_flashPageTitle()

  stopFlashingPageTitle: ->
    timer = @get('_pageTitleFlashTimer')
    if timer?
      Ember.run.cancel(timer)
      @set('_pageTitleFlashTimer', null)
    @_removePageTitleFlash()

  _flashPageTitle: ->
    if @get('_isShowingPageTitleFlash')
      @_removePageTitleFlash()
    else
      @_addPageTitleFlash()
    @set('_pageTitleFlashTimer', Ember.run.later(@, '_flashPageTitle', 1000))

  _removePageTitleFlash: ->
    $(document).attr('title', App.get('title'))
    @set('_isShowingPageTitleFlash', false)

  _addPageTitleFlash: ->
    titleObj = App.get('pageTitlesToFlash')[0]
    $(document).attr('title', "#{titleObj.get('title')} | #{App.get('title')}")
    @set('_isShowingPageTitleFlash', true)
