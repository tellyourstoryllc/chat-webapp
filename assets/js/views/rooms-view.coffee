App.RoomsView = Ember.View.extend

  isChooseStatusMenuVisible: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'documentClick', 'documentActive')

  didInsertElement: ->
    $(window).on 'resize', @resize
    $('html').on 'click', @documentClick
    $(document).on 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive
    Ember.run.later @, 'checkIfIdleTick', 5000

    Ember.run.schedule 'afterRender', @, ->
      @updateSize()

  willDestroyElement: ->
    $(window).off 'resize', @resize
    $('html').off 'click', @documentClick
    $(document).off 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive

  roomsLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @updateSize()
  ).observes('controller.roomsLoaded')

  resize: _.debounce (event) ->
    Ember.run @, ->
      @updateSize()
  , 5

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    $window = $(window)
    height = $window.height()
    height -= $('.navbar:first').outerHeight() ? 0
    height -= $('.current-user-status-bar').outerHeight() ? 0
    @$('.rooms-list').css
      height: height

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
      newStatus = status.get('name')
      # TODO: Wrap in transaction.
      App.get('currentUser').set('status', newStatus)
      App.get('api').updateUserStatus(newStatus)
      @closeChooseStatusMenu()
      return undefined

    logOut: ->
      @closeChooseStatusMenu()
      @get('controller').send('logOut')
      return undefined
