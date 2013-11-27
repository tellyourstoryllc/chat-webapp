App.RoomsView = Ember.View.extend

  isShowingRoomsSidebar: false

  isRoomMenuVisible: false

  isChooseStatusMenuVisible: false

  isStatusTextMenuVisible: false

  isSendingRoomAvatar: false

  isSendingRoomWallpaper: false

  activeRoom: Ember.computed.alias('controller.activeRoom')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'documentClick', 'documentActive', 'bodyKeyDown',
      'onChangeRoomAvatarFile', 'onChangeRoomWallpaperFile',
      'onToggleRoomsSidebarTouchStart')

  didInsertElement: ->
    $(window).on 'resize', @resize
    $('html').on 'click', @documentClick
    $(document).on 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive
    # Bind to the body so that it works regardless of where the focus is.
    $('body').on 'keydown', @bodyKeyDown
    @$('.room-avatar-file').on 'change', @onChangeRoomAvatarFile
    @$('.room-wallpaper-file').on 'change', @onChangeRoomWallpaperFile
    @$('.toggle-sidebar-tab').on 'touchstart mousedown', @onToggleRoomsSidebarTouchStart
    Ember.run.later @, 'checkIfIdleTick', 5000

    Ember.run.schedule 'afterRender', @, ->
      @updateSize()

  willDestroyElement: ->
    $(window).off 'resize', @resize
    $('html').off 'click', @documentClick
    $(document).off 'mousemove mousedown keydown touchstart wheel mousewheel DOMMouseScroll', @documentActive
    $('body').off 'keydown', @bodyKeyDown
    @$('.room-avatar-file').off 'change', @onChangeRoomAvatarFile
    @$('.room-wallpaper-file').off 'change', @onChangeRoomWallpaperFile
    @$('.toggle-sidebar-tab').off 'touchstart mousedown', @onToggleRoomsSidebarTouchStart

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
    # Ctrl.
    if event.ctrlKey && ! (event.shiftKey || event.metaKey || event.altKey)
      if event.which == 219      # [
        @get('controller').send('showPreviousRoom')
        event.preventDefault()
      else if event.which == 221 # ]
        @get('controller').send('showNextRoom')
        event.preventDefault()

  isRoomContentOutOfTheWay: Ember.computed.alias('isShowingRoomsSidebar')

  onToggleRoomsSidebarTouchStart: (event) ->
    Ember.run @, ->
      event.preventDefault()
      @toggleProperty('isShowingRoomsSidebar')

  activeRoomDidChange: (->
    # Reset file pickers.
    @$('.room-avatar-file, .room-wallpaper-file').val('')
    # When the user shows the sidebar and selects a room, hide the sidebar.
    @set('isShowingRoomsSidebar', false)
  ).observes('activeRoom')

  resize: _.debounce (event) ->
    Ember.run @, ->
      # If we had the sidebar showing, go back to the default by hiding it.
      @set('isShowingRoomsSidebar', false)

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
    height -= @$('.admin-room-actions').outerHeight(true) ? 0
    height -= @$('.invite-room-actions').outerHeight(true) ? 0
    @$('.room-members-sidebar .title').each ->
      height -= $(@).outerHeight(true) ? 0
    @$('.room-members').css
      height: height

  documentClick: (event) ->
    Ember.run @, ->
      @closeRoomMenu()
      @closeChooseStatusMenu()
      @closeStatusTextMenu()

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
    App.set('isIdle', secDiff >= 60 * App.get('preferences.clientWeb.showIdleAfterMinutes'))

  updateUserIdleDurations: ->
    now = new Date()
    App.User.all().forEach (user) =>
      user.set('mostRecentIdleDuration', user.idleDurationAsOfNow(now))

  currentlyViewingRoomChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      return unless @currentState == Ember.View.states.inDOM

      # Make sure the room menu is closed.
      @closeRoomMenu() if @get('isRoomMenuVisible')

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

  hasRoomAvatar: Ember.computed.notEmpty('activeRoom.avatarUrl')

  canUpdateRoomAvatar: (->
    room = @get('activeRoom')
    room instanceof App.Group && ! @get('isSendingRoomAvatar') &&
      room.get('isCurrentUserAdmin')
  ).property('activeRoom', 'activeRoom.isCurrentUserAdmin', 'isSendingRoomAvatar')

  onChangeRoomAvatarFile: (event) ->
    Ember.run @, ->
      file = event.target.files?[0]
      @_updateRoomAvatar(file) if file?

  # Persists the file to the API.  Use `null` file to remove it.
  _updateRoomAvatar: (file) ->
    return if @get('isSendingRoomAvatar')
    api = App.get('api')
    formData = new FormData()
    formData.append(k, v) for k,v of api.defaultParams()
    formData.append('avatar_image_file', file)
    @set('isSendingRoomAvatar', true)
    room = @get('activeRoom')
    api.ajax(room.updateAvatarUrl(), 'POST',
      data: formData
      processData: false
      contentType: false
    )
    .always =>
      @set('isSendingRoomAvatar', false)
    .then (json) =>
      if ! json || json.error?
        throw json
      App.loadAll(json)
    .fail App.rejectionHandler

  hasRoomWallpaper: Ember.computed.notEmpty('activeRoom.wallpaperUrl')

  canUpdateRoomWallpaper: (->
    room = @get('activeRoom')
    room instanceof App.Group && ! @get('isSendingRoomWallpaper') &&
      room.get('isCurrentUserAdmin')
  ).property('activeRoom', 'activeRoom.isCurrentUserAdmin', 'isSendingRoomWallpaper')

  onChangeRoomWallpaperFile: (event) ->
    Ember.run @, ->
      file = event.target.files?[0]
      @_updateRoomWallpaper(file) if file?

  # Persists the file to the API.  Use `null` file to remove it.
  _updateRoomWallpaper: (file) ->
    return if @get('isSendingRoomWallpaper')
    api = App.get('api')
    formData = new FormData()
    formData.append(k, v) for k,v of api.defaultParams()
    formData.append('wallpaper_image_file', file)
    @set('isSendingRoomWallpaper', true)
    room = @get('activeRoom')
    api.ajax(room.updateWallpaperUrl(), 'POST',
      data: formData
      processData: false
      contentType: false
    )
    .always =>
      @set('isSendingRoomWallpaper', false)
    .then (json) =>
      if ! json || json.error?
        throw json
      App.loadAll(json)
    .fail App.rejectionHandler

  showRoomMenu: ->
    @$('.room-menu').addClass('expand-down')
    @set('isRoomMenuVisible', true)

  closeRoomMenu: ->
    @$('.room-menu').removeClass('expand-down')
    @set('isRoomMenuVisible', false)

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
      @$('.new-status-text').focus()

  closeStatusTextMenu: ->
    @$('.status-text-menu').removeClass('expand-in-less-bounce')
    @set('isStatusTextMenuVisible', false)

  actions:

    toggleRoomMenu: ->
      if @get('isRoomMenuVisible')
        @closeRoomMenu()
      else
        @showRoomMenu()
      return undefined

    chooseRoomAvatar: ->
      activeRoom = @get('activeRoom')
      if ! activeRoom.get('isCurrentUserAdmin')
        if activeRoom instanceof App.OneToOne
          alert "The room avatar you see is set by the other user.  You can change your avatar from your settings dialog."
        else
          alert "You must be an admin to change the room wallpaper."
        return
      return unless @get('canUpdateRoomAvatar')
      @$('.room-avatar-file').trigger('click')
      return undefinedundefined

    removeRoomAvatar: ->
      activeRoom = @get('activeRoom')
      if ! activeRoom.get('isCurrentUserAdmin')
        if activeRoom instanceof App.OneToOne
          alert "The room avatar you see is set by the other user.  You can change your avatar from your settings dialog."
        else
          alert "You must be an admin to change the room avatar."
        return
      @$('.room-avatar-file').val('')
      @_updateRoomAvatar(null)
      return undefined

    chooseRoomWallpaper: ->
      activeRoom = @get('activeRoom')
      if ! activeRoom.get('isCurrentUserAdmin')
        if activeRoom instanceof App.OneToOne
          alert "The room wallpaper you see is set by the other user.  You can change your wallpaper from your settings dialog."
        else
          alert "You must be an admin to change the room wallpaper."
        return
      return unless @get('canUpdateRoomWallpaper')
      @$('.room-wallpaper-file').trigger('click')
      return undefined

    removeRoomWallpaper: ->
      activeRoom = @get('activeRoom')
      if ! activeRoom.get('isCurrentUserAdmin')
        if activeRoom instanceof App.OneToOne
          alert "The room wallpaper you see is set by the other user.  You can change your wallpaper from your settings dialog."
        else
          alert "You must be an admin to change the room wallpaper."
        return
      @$('.room-wallpaper-file').val('')
      @_updateRoomWallpaper(null)
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
