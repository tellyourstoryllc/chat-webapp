App.RoomsView = Ember.View.extend

  isMacGapIdle: false

  # Text from input textbox to join room.
  enteredJoinText: ''

  isShowingRoomsSidebar: false

  isChooseStatusMenuVisible: false

  isStatusTextMenuVisible: false

  isShowingContactActionsMenu: false
  closeContactActionsMenuTimer: null

  activeRoom: Ember.computed.alias('controller.activeRoom')

  allContacts: Ember.computed.alias('controller.allContacts')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'documentClick', 'documentActive', 'bodyKeyDown',
      'onMacGapActive', 'onMacGapIdle',
      'onToggleRoomsSidebarTouchStart')
    @showDefaultSidebarView()
    # Force computed properties.
    @get('isRoomContentOutOfTheWay')

  didInsertElement: ->
    @get('controller').set('roomsView', @)

    $(window).on 'resize', @resize
    $('html').on 'click', @documentClick
    $(document).on 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive
    if App.get('isMacGap')
      $(document).on 'systemactive', @onMacGapActive
      $(document).on 'systemidle', @onMacGapIdle
    # Bind to the body so that it works regardless of where the focus is.
    $('body').on 'keydown', @bodyKeyDown
    @$('.toggle-sidebar-tab').on 'touchstart mousedown', @onToggleRoomsSidebarTouchStart
    @$('.join-text').on 'keydown', @onJoinTextKeyDown
    @$('.join-text').on 'paste', @onJoinTextPaste
    @$('.join-text').on 'focus', @onJoinTextFocus
    # @$('.contacts-list').on 'click', '.contact-list-item', @onContactsListItemClick
    Ember.run.later @, 'checkIfIdleTick', 5000

    Ember.run.schedule 'afterRender', @, ->
      @updateSize()

  willDestroyElement: ->
    @get('controller').set('roomsView', null)

    $(window).off 'resize', @resize
    $('html').off 'click', @documentClick
    $(document).off 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive
    if App.get('isMacGap')
      $(document).off 'systemactive', @onMacGapActive
      $(document).off 'systemidle', @onMacGapIdle
    $('body').off 'keydown', @bodyKeyDown
    @$('.toggle-sidebar-tab').off 'touchstart mousedown', @onToggleRoomsSidebarTouchStart
    @$('.join-text').off 'keydown', @onJoinTextKeyDown
    @$('.join-text').off 'paste', @onJoinTextPaste
    @$('.join-text').off 'focus', @onJoinTextFocus
    # @$('.contacts-list').off 'click', '.contact-list-item', @onContactsListItemClick

  roomsLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @updateSize()
  ).observes('controller.roomsLoaded')

  bodyKeyDown: (event) ->
    # No key modifiers.
    if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
      if event.which == 27      # Escape
        @closeChooseStatusMenu()
        @closeStatusTextMenu()
        @closeContactActionsMenu()
    # Ctrl.
    if event.ctrlKey && ! (event.shiftKey || event.metaKey || event.altKey)
      if event.which == 219      # [
        @get('controller').send('showPreviousRoom')
        event.preventDefault()
      else if event.which == 221 # ]
        @get('controller').send('showNextRoom')
        event.preventDefault()

  isRoomContentOutOfTheWay: Ember.computed.alias('isShowingRoomsSidebar')

  isRoomContentOutOfTheWayChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @updateSize()
  ).observes('isRoomContentOutOfTheWay')

  onToggleRoomsSidebarTouchStart: (event) ->
    Ember.run @, ->
      event.preventDefault()
      room = @get('activeRoom')
      # Don't allow user toggling when in the lobby since they won't be able to
      # get back.
      if room?
        @toggleProperty('isShowingRoomsSidebar')
      return undefined

  activeRoomDidChange: (->
    # When the user shows the sidebar and selects a room, go to the default
    # sidebar state.
    @showDefaultSidebarView()
  ).observes('App.currentlyViewingRoom')

  resize: _.debounce (event) ->
    Ember.run @, ->
      # If we had the sidebar showing, go back to the default.
      @showDefaultSidebarView()

      Ember.run.schedule 'afterRender', @, 'updateSize'
  , 5

  showDefaultSidebarView: ->
    activeRoom = App.get('currentlyViewingRoom')
    if activeRoom?
      @set('isShowingRoomsSidebar', false)
    else
      # We're in the lobby, so show the rooms sidebar.
      @set('isShowingRoomsSidebar', true)

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    $window = $(window)

    height = $window.height()
    height -= $('.logo').outerHeight(true) ? 0
    height -= $('.left-sidebar-tab-handles').outerHeight(true) ? 0
    height -= $('.current-user-status-bar').outerHeight() ? 0
    height -= 3 # Extra pixels to line up perfectly.
    commonSidebarHeight = height
    # When Contacts tab is selected, height returns 0.
    height -= $('.rooms-tab-top-actions').outerHeight(true) || 48
    @$('.rooms-list').css
      height: height

    height = commonSidebarHeight
    # height -= $('.contacts-search-container').outerHeight(true) ? 0
    @$('.contacts-list').css
      height: height

    windowWidth = $window.width()
    width = windowWidth
    roomSidebarWidth = 240 # .room-sidebar room-sidebar-width
    roomContentMarginWidth = 10 # room-content-margin-width
    # Less than or equal to this window width, no sidebars are shown. This
    # should match the CSS.
    noSidebarsWidth = 515
    isNoSidebars = windowWidth <= noSidebarsWidth
    width -= if isNoSidebars then 0 else roomSidebarWidth
    @$('.room-content').css
      width: width
  
  documentClick: (event) ->
    Ember.run @, ->
      @closeChooseStatusMenu()
      @closeStatusTextMenu()
      @closeContactActionsMenu()
      return undefined

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
    isIdle = (! App.get('isMacGap') || @get('isMacGapIdle')) &&
      secDiff >= 60 * App.get('preferences.clientWeb.showIdleAfterMinutes')
    App.set('isIdle', isIdle)

  onMacGapIdle: (event) ->
    Ember.run @, ->
      @set('isMacGapIdle', true)
      lastActiveAt = App.get('lastActiveAt')
      macGapLastActiveAt = moment().subtract(30, 'seconds').toDate()
      if ! lastActiveAt? || macGapLastActiveAt.getTime() > lastActiveAt.getTime()
        App.set('lastActiveAt', macGapLastActiveAt)

  onMacGapActive: (event) ->
    Ember.run @, ->
      @set('isMacGapIdle', false)
      @didDetectActivity()

  updateUserIdleDurations: ->
    now = new Date()
    App.User.all().forEach (user) =>
      user.set('mostRecentIdleDuration', user.idleDurationAsOfNow(now))

  currentlyViewingRoomChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      return unless @currentState == Ember.View.states.inDOM

      # Make sure the room menu is closed.
      @closeRoomMenu() if @get('isRoomMenuVisible')
      @closeInviteDialog() if @get('isInviteDialogVisible')

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
  ).observes('App.currentlyViewingRoom', 'controller.roomsLoaded')

  notificationVolumeChanged: (->
    $audio = @$('.mention-sound, .receive-message-sound')
    $audio.prop('volume', App.get('preferences.clientWeb.notificationVolume') / 100.0)
  ).observes('App.preferences.clientWeb.notificationVolume')

  showAvatars: (->
    App.get('preferences.clientWeb.showAvatars')
  ).property('App.preferences.clientWeb.showAvatars')

  showChooseStatusMenu: ->
    @$('.choose-status-menu').addClass('expand-up')
    @set('isChooseStatusMenuVisible', true)

  closeChooseStatusMenu: ->
    @$('.choose-status-menu').removeClass('expand-up')
    @set('isChooseStatusMenuVisible', false)

  showStatusTextMenu: ->
    @$('.status-text-menu').addClass('expand-in-less-bounce')
    @set('isStatusTextMenuVisible', true)
    @$('.new-status-text').val(App.get('currentUser.statusText'))
    Ember.run.schedule 'afterRender', @, ->
      @$('.new-status-text').focus().textrange('set') # Select all.

  closeStatusTextMenu: ->
    @$('.status-text-menu').removeClass('expand-in-less-bounce')
    @set('isStatusTextMenuVisible', false)

  # Deactivate previous contact item and activate item for the given User.  User
  # can be `null`.
  activateContactItem: (user) ->
    # Set active list item.
    prevUser = @get('contactMenuContext')
    if prevUser? && prevUser != user
      @$("[data-user-id='#{prevUser.get('id')}']").removeClass('active')
    if user?
      @$("[data-user-id='#{user.get('id')}']").addClass('active')
    @set('contactMenuContext', user)

  showContactActionsMenu: (user, $listItem) ->
    @activateContactItem(user)

    # Move menu to correct position and show.
    $menu = @$('.contact-actions-menu')
    offset = $listItem.offset()
    if offset?
      $menu.css(top: offset.top)
    $menu.addClass('expand-in')
    @set('isShowingContactActionsMenu', true)

  closeContactActionsMenu: () ->
    @activateContactItem(null)
    @set('closeContactActionsMenuTimer', null)
    @$('.contact-actions-menu').removeClass('expand-in')
    @set('isShowingContactActionsMenu', false)

  startHideContactActionsMenuTimer: ->
    timer = Ember.run.later @, 'closeContactActionsMenu', 500
    @set('closeContactActionsMenuTimer', timer)

  clearHideContactActionsMenuTimer: ->
    timer = @get('closeContactActionsMenuTimer')
    if timer?
      Ember.run.cancel(timer)
      @set('closeContactActionsMenuTimer', null)

  # onContactsListItemClick: (event) ->
  #   Ember.run @, ->
  #     @clearHideContactActionsMenuTimer()

  #     target = event.target
  #     return unless target?
  #     $target = $(target).closest('.contact-list-item')
  #     userId = $target.attr('data-user-id')
  #     return unless userId?
  #     user = App.User.lookup(userId)
  #     if user?
  #       # Don't close the menu.
  #       event.stopPropagation()

  #       @showContactActionsMenu(user, $target)
  #     return undefined

  actions:

    toggleRoomsSidebar: ->
      @toggleProperty('isShowingRoomsSidebar')
      return undefined

    toggleChooseStatusMenu: ->
      if @get('isChooseStatusMenuVisible')
        @closeChooseStatusMenu()
      else
        @showChooseStatusMenu()
      @closeStatusTextMenu()
      return undefined

    setStatus: (status) ->
      App.get('api').updateCurrentUserStatus(status.get('name'))
      @closeChooseStatusMenu()
      return undefined

    changeStatusText: ->
      if ! @get('isStatusTextMenuVisible')
        @showStatusTextMenu()
      @closeChooseStatusMenu()
      return undefined

    saveStatusText: ->
      newStatusText = @$('.new-status-text').val()
      newStatusText = null if Ember.isEmpty(newStatusText)
      App.get('api').updateCurrentUserStatusText(newStatusText)
      return undefined

    logOut: ->
      @closeChooseStatusMenu()
      @get('controller').send('logOut')
      return undefined

    goToContactOneToOne: ->
      user = @get('contactMenuContext')
      return unless user?

      @get('controller').send('goToOneToOne', user)
      return undefined

    removeContact: ->
      user = @get('contactMenuContext')
      return unless user?

      if ! user.get('isContact')
        alert "You can't remove a contact when you're in a room with that person."
        return

      @get('controller').send('removeUserContacts', user)
      return undefined

    didFocusSendMessageText: ->
      @set('isShowingRoomsSidebar', false)
      return undefined
