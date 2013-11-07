App.RoomsView = Ember.View.extend

  isChooseStatusMenuVisible: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'documentClick', 'documentActive', 'bodyKeyDown')

  didInsertElement: ->
    $(window).on 'resize', @resize
    $('html').on 'click', @documentClick
    $(document).on 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive
    # Bind to the body so that it works regardless of where the focus is.
    $('body').on 'keydown', @bodyKeyDown
    Ember.run.later @, 'checkIfIdleTick', 5000

    Ember.run.schedule 'afterRender', @, ->
      @updateSize()

  willDestroyElement: ->
    $(window).off 'resize', @resize
    $('html').off 'click', @documentClick
    $(document).off 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive
    $('body').off 'keydown', @bodyKeyDown

  roomsLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @updateSize()
  ).observes('controller.roomsLoaded')

  bodyKeyDown: (event) ->
    # Ctrl.
    if event.ctrlKey && ! (event.shiftKey || event.metaKey || event.altKey)
      if event.which == 219      # [
        @get('controller').send('showPreviousRoom')
        event.preventDefault()
      else if event.which == 221 # ]
        @get('controller').send('showNextRoom')
        event.preventDefault()

  resize: _.debounce (event) ->
    Ember.run @, ->
      @updateSize()
  , 5

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    $window = $(window)
    isMembersVisible = $window.width() > 700

    height = $window.height()
    height -= $('.navbar:first').outerHeight() ? 0
    height -= $('.current-user-status-bar').outerHeight() ? 0
    @$('.rooms-list').css
      height: height

    @$('.room-members-sidebar').css
      display: if isMembersVisible then 'block' else 'none'

    # The list of members needs an explicit height so that it can be scrollable.
    height = $window.height()
    @$('.room-members').css
      height: height - @$('.room-members-sidebar .title').outerHeight(true)

  documentClick: (event) ->
    Ember.run @, ->
      @closeChooseStatusMenu()

  # Triggered on any user input, e.g. mouse, keyboard, touch, etc.
  documentActive: (event) ->
    Ember.run @, ->
      @didDetectActivity()

  windowHasFocusChanged: (->
    @didDetectActivity()
  ).observes('App.hasFocus')

  didDetectActivity: ->
    App.set('lastActiveAt', new Date())

  lastActiveAtChanged: (->
    @checkIfIdle()
  ).observes('App.lastActiveAt')

  checkIfIdleTick: ->
    @checkIfIdle()
    @updateUserIdleDurations()
    Ember.run.later @, 'checkIfIdleTick', 5000

  checkIfIdle: ->
    lastActiveAt = App.get('lastActiveAt')
    msDiff = new Date().getTime() - lastActiveAt.getTime()
    secDiff = Math.round(msDiff / 1000)
    App.set('idleForSeconds', secDiff)
    App.set('isIdle', secDiff >= 60 * App.get('showIdleAfterMinutes'))

  updateUserIdleDurations: ->
    now = new Date()
    App.User.all().forEach (user) =>
      user.set('mostRecentIdleDuration', user.idleDurationAsOfNow(now))

  currentlyViewingRoomChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      return unless @currentState == Ember.View.states.inDOM

      roomId = App.get('currentlyViewingRoom.id')
      if roomId?
        regexp = new RegExp("/#{App.Util.escapeRegexp(roomId)}$")
      else
        # We're in the lobby.
        regexp = new RegExp("/rooms$")

      $('.room-list-item a[href]').each ->
        $link = $(@)
        if regexp.test($link.prop('href') ? '')
          $link.addClass 'active'
        else
          $link.removeClass 'active'
  ).observes('App.currentlyViewingRoom')

  showChooseStatusMenu: ->
    @$('.choose-status-menu').fadeIn(50)
    @set('isChooseStatusMenuVisible', true)

  closeChooseStatusMenu: ->
    @$('.choose-status-menu').fadeOut(300)
    @set('isChooseStatusMenuVisible', false)

  actions:

    toggleChooseStatusMenu: ->
      if @get('isChooseStatusMenuVisible')
        @closeChooseStatusMenu()
      else
        @showChooseStatusMenu()
      return undefined

    setStatus: (status) ->
      App.get('api').updateCurrentUserStatus(status.get('name'))
      @closeChooseStatusMenu()
      return undefined

    logOut: ->
      @closeChooseStatusMenu()
      @get('controller').send('logOut')
      return undefined
