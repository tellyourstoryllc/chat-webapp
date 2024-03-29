# Contains everything specific to a single room, but for performance reasons,
# shared among all rooms.
#
# Actions: addUserContacts, removeUserContacts, didFocusSendMessageText,
#   didJoinGroup, didGoToRoom,
#   didCloseRoom, didToggleRoomsSidebar, willLeaveRoom
App.RoomsContainerComponent = Ember.Component.extend App.BaseControllerMixin,

  # Caller must bind this.
  activeRoom: null

  # Caller should bind this to sorted users for invite dialog autocomplete.
  arrangedContacts: null

  newRoomName: ''

  isEditingRoomName: false

  # Internally set to true after Flash is loaded.
  canCopyWithFlash: false

  copiedIndicatorTimer: null

  newRoomTopic: null

  isEditingTopic: false

  showSetPasswordBanner: false
  isSettingPassword: false
  setPasswordBannerErrorMessage: null

  showDownloadAppBanner: false

  numMembersToShow: 3

  isRoomMenuVisible: false

  # State for showing the invite dialog.
  isInviteDialogVisible: false
  inviteDialogAnimationTimer: null

  # State internal to the invite dialog.
  inviteDialogErrorMessage: null
  inviteDialogAlertIsError: false
  isSendingAddUsersToGroup: false

  # State for invite dialog user autocomplete.
  isAddUserSuggestionsShowing: false

  isSendingRoomAvatar: false

  isSendingRoomWallpaper: false

  isNoSidebars: false

  isShowingEncryptedUi: null

  # Set to true to display the rooms sidebar toggle instead of the room avatar.
  showRoomsSidebarToggle: Ember.computed.alias('isNoSidebars')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'bodyKeyDown', 'clickSender', 'onMessageFileChange',
      'onDocumentClick',
      'onTapRoomsSidebarToggle',
      'onDownloadMacAppClick',
      'onChangeRoomAvatarFile', 'onChangeRoomWallpaperFile',
      'onClickMessageLink',
      'onSendMessageTextFocus',
      'onSendMessageTextPaste', 'onSendMessageTextCursorMove',
      'onIe9KeyUp', 'sendMessageTextKeyDown', 'sendMessageTextInput')
    @set('suggestions', [])
    App.get('eventTarget').on 'didConnect', @, @didConnect

  didInsertElement: ->
    App.set('roomsContainerView', @)

    $(window).on 'resize', @resize
    # Bind to the body so that it works regardless of where the focus is.
    $('body').on 'keydown', @bodyKeyDown
    $(document).on 'click', @onDocumentClick
    $(document).on 'click', '.toggle-rooms-sidebar', @onTapRoomsSidebarToggle
    $(document).on 'click', '.message-body a[href]', @onClickMessageLink
    $(document).on 'click', '.sender', @clickSender
    $(document).on 'click', '.download-app-link', @onDownloadMacAppClick

    Ember.run.schedule 'afterRender', @, ->
      @$('.send-message-text').on 'keydown', @sendMessageTextKeyDown
      @$('.send-message-text').on 'keyup click', @onSendMessageTextCursorMove
      # `propertychange` is for IE8.
      @$('.send-message-text').on 'input propertychange', @sendMessageTextInput
      @$('.send-message-text').on 'keyup', @onIe9KeyUp if Modernizr.msie9
      @$('.send-message-text').on 'focus', @onSendMessageTextFocus
      @$('.send-message-text').on 'paste', @onSendMessageTextPaste
      @$('.send-message-file').on 'change', @onMessageFileChange
      @$('.room-avatar-file').on 'change', @onChangeRoomAvatarFile
      @$('.room-wallpaper-file').on 'change', @onChangeRoomWallpaperFile
      @updateSize()
      @setFocus()
      @setupCopyToClipboard()

  willDestroyElement: ->
    App.set('roomsContainerView', null)

    $(window).off 'resize', @resize
    $('body').off 'keydown', @bodyKeyDown
    $(document).off 'click', @onDocumentClick
    $(document).off 'click', '.toggle-rooms-sidebar', @onTapRoomsSidebarToggle
    $(document).off 'click', '.message-body a[href]', @onClickMessageLink
    $(document).off 'click', '.sender', @clickSender
    $(document).off 'click', '.download-app-link', @onDownloadMacAppClick
    @$('.send-message-text').off 'keydown', @sendMessageTextKeyDown
    @$('.send-message-text').off 'keyup click', @onSendMessageTextCursorMove
    @$('.send-message-text').off 'input propertychange', @sendMessageTextInput
    @$('.send-message-text').off 'keyup', @onIe9KeyUp if Modernizr.msie9
    @$('.send-message-text').off 'focus', @onSendMessageTextFocus
    @$('.send-message-text').off 'paste', @onSendMessageTextPaste
    @$('.send-message-file').off 'change', @onMessageFileChange
    @$('.room-avatar-file').off 'change', @onChangeRoomAvatarFile
    @$('.room-wallpaper-file').off 'change', @onChangeRoomWallpaperFile

  bodyKeyDown: (event) ->
    # No key modifiers.
    if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
      if event.which == 27 # Escape.
        # Hide dialogs.
        @closeRoomMenu() if @get('isRoomMenuVisible')
        if @get('isInviteDialogVisible') && ! @get('addUsersMultiselectView.areSuggestionsShowing')
          @closeInviteDialog()
          event.preventDefault()
          event.stopPropagation()
        # Cancel editing.
        if @get('isEditingRoomName')
          @set('isEditingRoomName', false)
        else if @get('isEditingTopic')
          @set('isEditingTopic', false)
        else
          # Focus on send message textarea.
          @setFocus(true)

  onTapRoomsSidebarToggle: (event) ->
    Ember.run @, ->
      @sendAction('didToggleRoomsSidebar')
      return undefined

  roomChanged: (->
    # Hide autocomplete suggestions.
    @set('suggestionsShowing', false)

    # If user was editing, cancel it.
    @setProperties(isEditingRoomName: false, isEditingTopic: false)

    # Make sure copy to clipboard is setup.
    Ember.run.scheduleOnce 'afterRender', @, 'setupCopyToClipboard'

    Ember.run.schedule 'afterRender', @, ->
      # Reset file pickers.
      @$('.room-avatar-file, .room-wallpaper-file').val('')

      # Show invite dialog.  Run this after the hide animation completes.
      Ember.run.later @, ->
        @resetInviteDialogState()

        room = @get('activeRoom')
        if room?.needsInviteTip?()
          @send('toggleInviteDialogOverMessages')
      , 300

    # Yield to the UI before setting focus since it forces layout.
    App.nextFrame =>
      Ember.run.schedule 'afterRender', @, ->
        @setFocus(false)
  ).observes('activeRoom')

  roomAssociationsLoadedChanged: (->
    App.nextFrame =>
      if @get('activeRoom.associationsLoaded')
        Ember.run.schedule 'afterRender', @, ->
          @setFocus(false)
  ).observes('activeRoom.associationsLoaded')

  isSendDisabled: (->
    ! @get('activeRoom.associationsLoaded') || ! @get('activeRoom.isCurrentUserMember')
  ).property('activeRoom.associationsLoaded', 'activeRoom.isCurrentUserMember')

  didConnect: ->

  roomsChanged: (->
    # If a room gets added later, it needs to get sized.
    Ember.run.scheduleOnce 'afterRender', @, 'updateMessagesSize'
  ).observes('rooms.@each.associationsLoaded')

  click: (event) ->
    room = @get('activeRoom')
    # If the room's view is scrolled to the bottom, mark it as seen.
    if room? && App.roomMessagesViewFromRoom(room)?.isScrolledToLastMessage()
      room.markLastMessageAsSeen()

  onDocumentClick: (event) ->
    Ember.run @, ->
      return if App.Util.isMouseEventWithin(event, '.invite-dialog')
      @closeRoomMenu() if @get('isRoomMenuVisible')
      @closeInviteDialog() if @get('isInviteDialogVisible')
      return undefined

  resize: _.debounce (event) ->
    Ember.run @, ->
      Ember.run.scheduleOnce 'afterRender', @, 'updateSize'
  , 5

  showAddMembersButton: (->
    @get('isLoggedIn') && @get('activeRoom.isCurrentUserMember')
  ).property('isLoggedIn', 'activeRoom.isCurrentUserMember')

  activeRoomIsEncryptedChanged: (->
    # If encrypted state actually changed, update the UI sizes.
    isShowingEncryptedUi = @get('isShowingEncryptedUi')
    if ! isShowingEncryptedUi? || @get('activeRoom.isEncrypted') != isShowingEncryptedUi
      Ember.run.scheduleOnce 'afterRender', @, 'updateSize'
  ).observes('activeRoom.isEncrypted')

  activeRoomArrangedMembers: (->
    room = @get('activeRoom')
    return null unless room?
    room.get('arrangedByIdMembers')
  ).property('activeRoom.arrangedByIdMembers')

  allUsers: (->
    App.User.allArrangedById()
  ).property()

  activeRoomUsersLoaded: (->
    # TODO: Load all contacts.
    room = @get('activeRoom')
    ! room? || room.get('usersLoaded')
  ).property('activeRoom.usersLoaded')

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    $window = $(window)
    windowWidth = $window.width()

    # Less than or equal to this window width, no sidebars are shown. This
    # should match the CSS.
    noSidebarsWidth = 515
    isNoSidebars = windowWidth <= noSidebarsWidth
    @set('isNoSidebars', isNoSidebars)

    containerHeight = @containerHeight($window)
    height = containerHeight
    height -= @$('.room-info').outerHeight() ? 0
    messagesWidth = @messagesWidth($window)
    width = messagesWidth
    @$('.room-container-messages').css
      width: width
      height: height

    # Autocomplete suggestions height.
    @$('.autocomplete').css
      'max-height': height - 100
      'overflow-y': 'auto'

    # The send message area, including textarea and send button.
    @$('.send-message-area').css
      width: width
    # The send message text input.
    textWidth = width
    textWidth -= @$('.send-button').outerWidth(true) + 18
    @$('.send-message-text').css
      width: Math.max(10, textWidth)

    # Send button text width can vary due to encryption.
    @set('isShowingEncryptedUi', @get('activeRoom.isEncrypted'))
    sendButtonWidth = @$('.send-button').outerWidth(true)

    # Emoticon picker button.
    @$('.message-emoticon-icon').css
      right: sendButtonWidth + 18 + 29
    # The send message file button.
    if App.doesBrowserSupportAjaxFileUpload()
      @$('.message-attach-icon').css
        right: sendButtonWidth + 18

    @updateMessagesSize($window, containerHeight, messagesWidth)

    isMembersVisible = $window.width() > 700
    $('.room-members-sidebar').css
      left: messagesWidth
      top: @$('.room-info').outerHeight() ? 0
      height: height
      display: if isMembersVisible then 'block' else 'none'

    # The list of members needs an explicit height so that it can be scrollable.
    height = $window.height()
    height -= 2 * 10 # .room-content margin height.
    height -= $('.room-info').outerHeight(true) ? 0
    height -= @$('.invite-button-container').outerHeight(true) ? 0
    @$('.users-list-component').css
      height: height

  containerHeight: ($window = $(window)) ->
    height = $window.height()
    height -= 2 * 10 # .room-content margin height.
    height

  updateMessagesSize: ($window = $(window), containerHeight = @containerHeight($window), messagesWidth = @messagesWidth($window)) ->
    # This method needs to work for multiple message view elements.

    height = containerHeight
    height -= @$('.room-info').outerHeight() ? 0
    height -= @$('.send-message-area').outerHeight(true) ? 0

    activeRoom = @get('activeRoom')
    $('.messages').each ->
      $e = $(@)
      $parent = $e.closest('.room-messages-view')
      roomMessagesView = App._viewFromElement($parent)
      roomMessagesView.updateSize(height, activeRoom, $e)

    # Loading more messages bar at the top.
    $loadingMoreMessages = $('.loading-more-messages')
    loadingMessagesWidth = $loadingMoreMessages.width()
    $loadingMoreMessages.css
      left: Math.round((messagesWidth - loadingMessagesWidth) / 2)

  # Returns the width of the list of messages in pixels.
  messagesWidth: ($window = $(window)) ->
    windowWidth = $window.width()
    isMembersVisible = windowWidth > 700
    # Less than or equal to this window width, no sidebars are shown. This
    # should match the CSS.
    noSidebarsWidth = 515
    isNoSidebars = windowWidth <= noSidebarsWidth
    membersSidebarWidth = 200 # .room-members-sidebar
    roomsSidebarWidth = if isNoSidebars
      0
    else
      $('.rooms-sidebar').outerWidth()
    width = windowWidth
    width -= 2 * 10 # .room-content margin width.
    width -= roomsSidebarWidth ? 0
    width -= membersSidebarWidth if isMembersVisible
    width

  isActiveRoomOneToOne: (->
    @get('activeRoom') instanceof App.OneToOne
  ).property('activeRoom')

  isActiveRoomUserContact: (->
    room = @get('activeRoom')
    return false unless room?
    room.get('otherUser.isContact')
  ).property('activeRoom.otherUser.isContact')

  isActiveRoomServerAllMessagesEmailEnabled: (->
    room = @get('activeRoom')
    return null unless room instanceof App.Group
    room.get('serverAllMessagesEmail')
  ).property('activeRoom.serverAllMessagesEmail')

  activeRoomAvatarStyle: (->
    url = @get('activeRoom.avatarUrl')
    return null unless url?
    "background-image: url('#{url}')"
  ).property('activeRoom.avatarUrl')

  canEditRoomName: (->
    room = @get('activeRoom')
    room instanceof App.Group && room.get('isCurrentUserAdmin')
  ).property('activeRoom', 'activeRoom.isCurrentUserAdmin')

  showSetTopicLink: (->
    @get('activeRoom.canSetTopic') && Ember.isEmpty(@get('activeRoom.topic')) &&
      ! @get('isEditingTopic')
  ).property('activeRoom.canSetTopic', 'activeRoom.topic', 'isEditingTopic')

  needsPasswordChanged: (->
    if App.get('currentUser.account.needsPassword')
      @set('showSetPasswordBanner', true)
  ).observes('App.currentUser.account.needsPassword').on('didInsertElement')

  needsDownloadMacAppChanged: (->
    if App.get('needsMacApp')
      shouldShow = true
      # If the user dismissed the banner before, don't show it again for 3 days.
      str = window.localStorage.getItem('dismissedDownloadAppBanner')
      if ! Ember.isEmpty(str) && (date = App.Util.deserializeDate(str))?
        shouldShow = moment().diff(moment(date), 'days') >= 3
        if shouldShow
          # Clear it out to save space.
          window.localStorage.removeItem('dismissedDownloadAppBanner')

      if shouldShow
        @set('showDownloadAppBanner', true)
  ).observes('App.needsMacApp').on('didInsertElement')

  roomAlphabeticMembers: (->
    members = @get('activeRoom.alphabeticMembers')
    return null unless members?
    members[0 ... @get('numMembersToShow')]
  ).property('activeRoom.alphabeticMembers.[]', 'numMembersToShow')

  roomNumberMoreMembers: (->
    len = @get('activeRoom.alphabeticMembers.length')
    return null unless len?
    Math.max(0, len - @get('numMembersToShow'))
  ).property('activeRoom.alphabeticMembers.length', 'numMembersToShow')

  setFocus: (force) ->
    # Don't auto-focus on mobile since it opens the on-screen keyboard.
    if force || ! (Modernizr.appleios || Modernizr.android)
      @$('.send-message-text')?.focus()

  onDownloadMacAppClick: (event) ->
    Ember.run @, ->
      App.Analytics.trackEvent 'download', category: 'app', label: 'Mac App'
      # Do the default.

      # Hide the banner.
      @set('showDownloadAppBanner', false)
      window.localStorage.setItem('dismissedDownloadAppBanner', App.Util.serializeDate(new Date()))
      return undefined

  onClickMessageLink: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
        href = $(event.target).prop('href')
        internalPath = App.internalUrlPath(href)
        if ! Ember.isEmpty(internalPath)
          # Found internal link.
          transitioned = @transitionToInternalPath(internalPath)
          # If we were able to attempt a transition, don't load the link in the
          # browser.
          event.preventDefault() if transitioned
      return undefined

  # Returns true if transition was attempted.
  transitionToInternalPath: (path) ->
    if /^\/rooms(\/|$)/.test(path)
      # Room permalink.  Just go to it.
      router = App._getRouter()
      router.location.setURL(path)
      router.handleURL(path)
      true
    else if (matches = /^\/join\/([a-zA-Z0-9]+)/.exec(path))
      # Join link.  Load the room and display the members to give the user the
      # option to enter it.
      App.Group.fetchByJoinCode(matches[1]).then (json) =>
        group = App.Group.loadSingle(json)
        @sendAction('didGoToRoom', group) if group?
      true
    else
      false

  # When clicking a name, insert @name to mention that user.
  clickSender: (event) ->
    Ember.run @, ->
      messageId = $(event.target).closest('.message').attr('data-message-id')
      return if Ember.isEmpty(messageId)

      message = App.Message.lookup(messageId)
      return unless message?

      user = message.get('user')
      return unless user?

      textarea = @$('.send-message-text')
      return unless textarea

      event.preventDefault()

      # Insert mention text.
      textarea.textrange('replace', "@#{user.get('mentionName')} ")

      # Deselect the text we just inserted by moving the cursor to the end.
      curSel = textarea.textrange('get')
      if curSel?.end?
        textarea.textrange('set', curSel.end, 0)

  onSendMessageTextCursorMove: (event) ->
    Ember.run @, ->
      prevPosition = @get('textCursorPosition')
      if prevPosition?
        # We're matching autocomplete text.  If the cursor really moved, update
        # suggestions and/or hide them.
        $text = @$('.send-message-text')
        range = $text.textrange('get')
        if range.position != prevPosition
          @showAutocomplete()

  onIe9KeyUp: (event) ->
    Ember.run @, ->
      # This is to work around the fact that IE9 doesn't trigger the input event
      # when pressing backspace or delete.
      if event.which in [8, 46] # Backspace, delete.
        @sendMessageTextInput(event)
      return undefined

  sendMessageTextKeyDown: (event) ->
    Ember.run @, ->
      if event.ctrlKey && ! (event.altKey || event.shiftKey || event.metaKey)
        switch event.which
          when 32 # Space.
            # Show autocomplete.
            @showAutocomplete()
            event.preventDefault()
      # The following are only for when the autocomplete suggestions are
      # showing.
      return unless @get('suggestionsShowing')
      # The suggestion popup is open.  Detect cursor movement and selection.
      switch event.which
        when 9 # Tab.
          @get('autocompleteView').send('selectCurrentSuggestion')
          event.preventDefault()
        when 13 # Enter.
          @get('autocompleteView').send('selectCurrentSuggestion')
          event.preventDefault()
          # For enter, we must stop propagation also; otherwise it sends the
          # message.
          event.stopPropagation()
        when 27 # Escape.
          if @get('suggestionsShowing')
            # Hide suggestions.
            @set('suggestionsShowing', false)
            event.preventDefault()
            event.stopPropagation()
        when 38 # Arrow up.
          @get('autocompleteView').send('moveCursorUp')
          event.preventDefault()
        when 40 # Arrow down.
          @get('autocompleteView').send('moveCursorDown')
          event.preventDefault()
      return undefined

  sendMessageTextInput: (event) ->
    Ember.run @, ->
      if @get('suggestionsShowing') && event.which in [9, 13, 38, 40]
        # User is interacting with the autocomplate view.
        return
      if event.which in [27]
        # Escape is a special case.  Always ignore it.
        return

      @showAutocomplete()
      return undefined

  # options
  # - mode String one of {auto|emoticons}.  If auto, uses message text.  If
  #        emoticons, ignores text and shows all emoticons.
  showAutocomplete: (options = {}) ->
    mode = options.mode ? 'auto'

    # Find any @text before the cursor.
    $text = @$('.send-message-text')
    text = $text.val()
    range = $text.textrange('get')
    beforeCursorText = text[0 ... range.position]
    matches = /(?:^|\W)(@\S*)$/.exec(beforeCursorText)
    if mode == 'auto' && matches
      # @text found; now figure out which names to suggest.
      @setProperties(suggestMatchText: matches[1], textCursorPosition: range.position)
      lowerCasedInputName = matches[1][1..].toLowerCase()
      newSuggestions = []

      # @all is always first.
      if 'all'.indexOf(lowerCasedInputName) == 0
        newSuggestions.pushObject Ember.Object.create
          name: null
          value: '@all'
          isAll: true

      # Filter users.
      users = @get('activeRoom.arrangedMembers')
      filteredUsers = users.filter (u) ->
        u.get('suggestFor').any (s) -> s.indexOf(lowerCasedInputName) == 0

      # Move current user to the bottom of suggestions.
      currentUser = App.get('currentUser')
      index = filteredUsers.indexOf(currentUser)
      if index >= 0
        filteredUsers.removeAt(index)
        filteredUsers.pushObject(currentUser)

      # Convert to suggestion object.
      userSuggestions = filteredUsers.map (u) ->
        Ember.Object.create
          name: u.get('name')
          value: "@" + u.get('mentionName')
          user: u
      newSuggestions.pushObjects(userSuggestions)
    else if mode == 'auto' && (matches = /(?:^|\W)(:\w*)$/.exec(beforeCursorText)) || mode == 'emoticons'
      # `:text` found; now figure out which emoticons to suggest.
      matchText = if mode == 'emoticons' then '' else matches[1]
      @setProperties(suggestMatchText: matchText, textCursorPosition: range.position)
      lowerCasedInputName = matchText.toLowerCase()
      newSuggestions = []

      emoticons = App.Emoticon.allArranged()
      emoticonSuggestions = emoticons.filter (e) ->
        e.get('name').toLowerCase().indexOf(lowerCasedInputName) == 0
      .map (e) ->
        Ember.Object.create
          imageUrl: e.get('imageUrl')
          value: e.get('name')
      newSuggestions.pushObjects(emoticonSuggestions)
    else
      # Nothing interesting before the cursor.
      @setProperties(suggestMatchText: null, textCursorPosition: null)
      newSuggestions = []

    if Ember.isEmpty(newSuggestions)
      # Hide instead of removing all elements so we get a nice visual effect.
      @set('suggestionsShowing', false)
    else
      @set('suggestions', newSuggestions)
      @set('suggestionsShowing', true)

  onSendMessageTextFocus: (event) ->
    Ember.run @, ->
      @sendAction('didFocusSendMessageText')
      return undefined

  onSendMessageTextPaste: (event) ->
    Ember.run @, ->
      # User pasted something into the message text input.
      dataTransfer = event.originalEvent.clipboardData
      file = dataTransfer?.files[0]
      if ! file? && dataTransfer?.items
        # `items` is a `DataTransferItemList`, which is an array-like object but
        # without all the slick array methods.
        for i in [0 ... dataTransfer.items.length]
          item = dataTransfer.items[i]
          if item.kind == 'file' && item.getAsFile?
            file = item.getAsFile()
            break if file?
      if file?
        # If we found a file, prevent default and attach it.
        event.preventDefault()
        @send('attachFile', file)

  onMessageFileChange: (event) ->
    Ember.run @, ->
      file = if event.target.files?
        event.target.files[0]
      else if event.target.value
        name: event.target.value.replace(/^.+\\/, '')

      # The user canceled; don't do anything.
      return if ! file?

      @setFileAttachment(file)

      return undefined

  clearFile: ->
    @$('.send-message-file').val('')
    @set('activeRoom.newMessageFile', null)

  setFileAttachment: (file) ->
    if file?
      @set('activeRoom.newMessageFile', file)
    else
      @clearFile()

  resetNewMessage: ->
    @set('activeRoom.newMessageText', '')
    @clearFile()

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
    # Safari and WebUI send the string "null" so make sure to use empty string.
    formData.append('avatar_image_file', file ? '')
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
    .catch App.rejectionHandler

    # Clear out the file input so that selecting the same file again triggers a
    # change event.
    @$('.room-avatar-file').val('')

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
    # Safari and WebUI send the string "null" so make sure to use empty string.
    formData.append('wallpaper_image_file', file ? '')
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
    .catch App.rejectionHandler

    # Clear out the file input so that selecting the same file again triggers a
    # change event.
    @$('.room-wallpaper-file').val('')

  showRoomMenu: ->
    @get('activeRoom')?.loadUserGroupPreferences?()

    @$('.room-menu').addClass('expand-down')
    @set('isRoomMenuVisible', true)

  closeRoomMenu: ->
    @$('.room-menu').removeClass('expand-down')
    @set('isRoomMenuVisible', false)

  setupCopyToClipboard: ->
    return if @get('zeroClipboard')? || ! @get('activeRoom')?
    clip = new ZeroClipboard(@$('.copy-join-link-button'))
    @set('zeroClipboard', clip)
    clip.on 'load', (client, args) =>
      Ember.run @, ->
        # Flash has been loaded.  Indicate in the UI that clicking copies.
        @set('canCopyWithFlash', true)

        client.on 'complete', (client, args) =>
          Ember.run @, ->
            # Copied to clipboard.  Show indicator.
            $tooltip = @$('.copy-to-clipboard-tooltip')
            $tooltip.attr('data-orig-text', $tooltip.text()) if ! $tooltip.attr('data-orig-text')
            $tooltip.addClass('copied-pulse')
            $tooltip.text('Copied!')
            timer = @get('copiedIndicatorTimer')
            Ember.run.cancel(timer) if timer?
            timer = Ember.run.later @, ->
              @set('copiedIndicatorTimer', null)
              $tooltip = @$('.copy-to-clipboard-tooltip')
              $tooltip.text($tooltip.attr('data-orig-text'))
              $tooltip.removeClass('copied-pulse')
            , 1000 # Animation duration.
            @set('copiedIndicatorTimer', timer)

  showInviteDialog: ->
    $dialog = @$('.invite-dialog')
    $dialog.css
      transform: "scale(0.6) translateY(-10%) translateX(10%)"
    $dialog.addClass('invite-dialog-animate-in')

    @set('isInviteDialogVisible', true)

    timer = @get('inviteDialogAnimationTimer')
    if timer?
      Ember.run.cancel(timer)
      @set('inviteDialogAnimationTimer', null)
    Ember.run.schedule 'afterRender', @, ->
      @get('addUsersMultiselectView').focus()

  closeInviteDialog: ->
    $dialog = @$('.invite-dialog')
    if $dialog.hasClass('over-messages')
      # When hiding, animate towards the Invite button to show users where it
      # is.
      translateX = Math.round(@$('.room-container-messages').width() / 2.0) + 160
      $dialog.css
        transform: "scale(0.6) translateY(-30%) translateX(#{translateX}px)"

      # After the animation completes, reset to default not-over-messages state.
      timer = Ember.run.later @, ->
        @set('inviteDialogAnimationTimer', null)
        @$('.invite-dialog')?.removeClass('over-messages').css left: ''
      , 300
      @set('inviteDialogAnimationTimer', timer)
    else
      # Hide normally.
      #
      # Note: If you change this, also change the showInviteDialog code.
      $dialog.css
        transform: "scale(0.6) translateY(-10%) translateX(10%)"

    $dialog.removeClass('invite-dialog-animate-in')
    @set('isInviteDialogVisible', false)

  resetInviteDialogState: ->
    @setProperties
      isAddUserSuggestionsShowing: false
      inviteDialogErrorMessage: null
    @get('addUsersMultiselectView').clear()

  isAddUsersToGroupDisabled: Ember.computed.alias('isSendingAddUsersToGroup')

  isAddMemberTextValid: (text) ->
    # Simple email-ish regex.
    /.*\S.*@\S+\.[a-zA-Z0-9\-]{2,}/.test(text)

  actions:

    editRoomName: ->
      @setProperties(isEditingRoomName: true, newRoomName: @get('activeRoom.name'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.edit-room-name').focus().textrange('set') # Select all.
      return undefined

    cancelEditingRoomName: ->
      @set('isEditingRoomName', false)
      return undefined

    saveRoomName: ->
      @set('isEditingRoomName', false)
      room = @get('activeRoom')
      room.updateName(@get('newRoomName'))
      return undefined

    editTopic: ->
      @setProperties(isEditingTopic: true, newRoomTopic: @get('activeRoom.topic'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.edit-topic').focus().textrange('set') # Select all.
      return undefined

    cancelEditingTopic: ->
      @set('isEditingTopic', false)
      return undefined

    dismissSetPasswordBanner: ->
      @set('showSetPasswordBanner', false)
      return undefined

    dismissDownloadAppBanner: ->
      @set('showDownloadAppBanner', false)
      window.localStorage.setItem('dismissedDownloadAppBanner', App.Util.serializeDate(new Date()))
      return undefined

    setPassword: ->
      return if @get('isSettingPassword')
      password = @$('.set-password-input').val() ? ''
      minPasswordLength = App.Account.minPasswordLength()
      if password.length < minPasswordLength
        @set('setPasswordBannerErrorMessage', "Password must be at least #{minPasswordLength} characters.")
        return

      @set('isSettingPassword', true)
      @set('setPasswordBannerErrorMessage', null)
      data =
        new_password: password
      api = App.get('api')
      api.ajax(api.buildURL('/accounts/update'), 'POST', data: data, skipLogOutOnInvalidTokenFilter: true)
      .always =>
        @set('isSettingPassword', false)
      .then (json) =>
        if ! json? || json.error?
          @set('setPasswordBannerErrorMessage', App.userMessageFromError(json))
          return
        @set('showSetPasswordBanner', false)
        App.get('currentUser.account')?.set('needsPassword', false)
        return undefined
      , (xhr) =>
        @set('setPasswordBannerErrorMessage', App.userMessageFromError(xhr))
        return undefined
      .catch App.rejectionHandler

      return undefined

    joinGroup: ->
      room = @get('activeRoom')
      return unless room?
      return if room.get('isJoining')

      joinCode = room.get('enteredJoinCode')
      # If no code is specified, use group ID for public rooms.
      if room.get('canJoinWithoutCode') && Ember.isEmpty(joinCode)
        joinCode = room.get('id')
      return if Ember.isEmpty(joinCode)

      room.set('isJoining', true)
      App.get('api').joinGroup(joinCode)
      .always =>
        room.set('isJoining', false)
      .then (group) =>
        # Reset form.
        room.set('enteredJoinCode', '')
        @sendAction('didJoinGroup', group)
      return undefined

    saveTopic: ->
      @set('isEditingTopic', false)
      room = @get('activeRoom')
      room.updateTopic(@get('newRoomTopic'))
      return undefined

    chooseEmoticon: ->
      if @get('suggestionsShowing')
        # If we're already showing emoticons, just hide them.
        @set('suggestionsShowing', false)
        return

      @showAutocomplete(mode: 'emoticons')
      return undefined

    chooseFile: ->
      @$('.send-message-file').trigger('click')
      return undefined

    removeAttachment: ->
      @clearFile()
      return undefined

    attachFile: (file) ->
      @setFileAttachment(file)
      return undefined

    attachUrl: (url) ->
      @$('.send-message-text').textrange('replace', url)
      return undefined

    didSelectSuggestion: (suggestion) ->
      # User selected a suggestion.  Expand the value into the text.
      $text = @$('.send-message-text')
      text = $text.val()
      suggestMatchText = @get('suggestMatchText')
      textCursorPosition = @get('textCursorPosition')
      matchLen = suggestMatchText.length
      textLeftOfExpansion = text[0...textCursorPosition - matchLen]
      expandedText = suggestion.get('value')
      newText = textLeftOfExpansion + expandedText + ' ' + text[textCursorPosition..]
      $text.val(newText)
      $text.trigger('input')
      # Move the cursor to the end of the expansion.
      $text.textrange('set', textLeftOfExpansion.length + expandedText.length + 1, 0)
      return undefined

    sendMessage: ->
      text = @get('activeRoom.newMessageText')
      file = @get('activeRoom.newMessageFile')
      return if Ember.isEmpty(text) && Ember.isEmpty(file)

      convo = @get('activeRoom')
      msg = App.Message.create
        clientId: App.Util.generateGuid()
        userId: App.get('currentUser.id')
        groupId: convo instanceof App.Group && convo.get('id')
        oneToOneId: convo instanceof App.OneToOne && convo.get('id')
        localText: text
        attachmentFile: file
        mentionedUserIds: App.Message.mentionedIdsInText(text, convo.get('members'))
      App.Message.sendNewMessage(msg)
      .then null, (e) =>
        Ember.Logger.error e, e?.stack ? e?.stacktrace
        # The internal error message isn't helpful to users.
        # userMsg = e?.error?.message ? e?.message
        userMsg = undefined
        # Stale client error.
        userMsg = "There was an error sending this message.  Wait a minute and try again." if /^1000:/.test(userMsg)
        msg.setProperties
          isError: true
          errorMessage: userMsg ? "There was an error sending this message."

      @resetNewMessage()
      @get('activeRoom').didReceiveMessage(msg, suppressNotifications: true, forceScroll: true)

      # Get permission to show desktop notifications since it must be done in
      # response to a user event.
      @get('targetObject').send('requestNotificationPermission')

      # On mobile devices, hide the keyboard after sending a message.
      if Modernizr.appleios || Modernizr.android
        @$('.send-message-text').blur()

      return undefined

    toggleRoomMenu: ->
      @closeInviteDialog()
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
          alert "You must be an admin to change the room avatar."
        return
      return unless @get('canUpdateRoomAvatar')
      @$('.room-avatar-file').trigger('click')
      return undefined

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

    disableRoomNotifications: ->
      room = @get('activeRoom')
      return unless room instanceof App.Group
      room.updateServerAllMessagesEmail(false)

    enableRoomNotifications: ->
      room = @get('activeRoom')
      return unless room instanceof App.Group
      room.updateServerAllMessagesEmail(true)

    leaveRoom: ->
      room = @get('activeRoom')
      return unless room?

      if room.isPropertyLocked('isDeleted')
        Ember.Logger.warn "I can't delete a room when I'm still waiting for a response from the server."
        return

      return if ! window.confirm("Permanently leave the \"#{room.get('name')}\" room?")

      # Notify up the chain before closing so that it knows where to transition
      # to.
      @sendAction('willLeaveRoom', room)

      api = App.get('api')
      url = api.buildURL("/groups/#{room.get('id')}/leave")
      room.withLockedPropertyTransaction url, 'POST', {}, 'isDeleted', =>
        room.set('isDeleted', true)
      , =>
        room.set('isDeleted', false)
      .then =>
        # Make sure the transaction succeeded.
        if room.get('isDeleted')
          # Stop listening for messages.
          room.set('isOpen', false)

      return undefined

    addUserToContacts: ->
      room = @get('activeRoom')
      return unless room?
      user = room.get('otherUser')
      return unless user?
      if user == App.get('currentUser')
        alert "You can't add yourself as a contact."
        return

      @sendAction('addUserContacts', user)
      return undefined

    removeUserFromContacts: ->
      room = @get('activeRoom')
      return unless room?
      user = room.get('otherUser')
      return unless user?
      @sendAction('removeUserContacts', user)
      return undefined

    hideRoom: ->
      room = @get('activeRoom')
      return unless room?
      @sendAction('didCloseRoom', room)
      return undefined

    toggleInviteDialogOverMessages: ->
      $dialog = @$('.invite-dialog')
      $parent = @$('.room-container-messages')
      if $dialog && $parent
        $dialog.addClass('over-messages').css
          left: Math.round(($parent.width() - $dialog.outerWidth()) / 2)
      @showInviteDialog()
      return undefined

    toggleInviteDialog: ->
      @showInviteDialog()
      return undefined

    dismissInviteDialog: ->
      @closeInviteDialog()
      return undefined

    addUsersToGroup: ->
      return if @get('isSendingAddUsersToGroup')
      room = @get('activeRoom')
      return unless room instanceof App.Group

      data = {}
      userIds = []
      emails = []
      isAdding = false
      @get('addUsersMultiselectView.userSelections').forEach (selection) =>
        u = selection.get('object')
        if u instanceof App.User
          userIds.push(u.get('id'))
        else
          emails.push(selection.get('name'))

      if userIds.length > 0
        data.user_ids = userIds.join(',')
        isAdding = true

      if emails.length > 0
        data.emails = emails.join(',')
        isAdding = true

      if ! isAdding
        @setProperties
          inviteDialogErrorMessage: "Start typing a contact name or enter an email address."
          inviteDialogAlertIsError: true
        return

      @set('isSendingAddUsersToGroup', true)
      @set('inviteDialogErrorMessage', null)
      api = App.get('api')
      api.ajax(api.buildURL("/groups/#{room.get('id')}/add_users"), 'POST', data: data)
      .always =>
        @set('isSendingAddUsersToGroup', false)
      .then (json) =>
        if ! json? || json.error?
          @setProperties
            inviteDialogErrorMessage: App.userMessageFromError(json)
            inviteDialogAlertIsError: true
          return
        # Success!
        App.loadAll(json)

        # Clear dialog.
        @get('addUsersMultiselectView').clear()

        # Hide the dialog.
        @closeInviteDialog()
      .catch (xhr) =>
        @setProperties
          inviteDialogErrorMessage: App.userMessageFromError(xhr)
          inviteDialogAlertIsError: true

    goToRoom: (room) ->
      @sendAction('didGoToRoom', room)
      return undefined
