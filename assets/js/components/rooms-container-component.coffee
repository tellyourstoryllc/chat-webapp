# Contains everything specific to a single room, but for performance reasons,
# shared among all rooms.
App.RoomsContainerComponent = Ember.Component.extend App.BaseControllerMixin,

  # Caller must bind this.
  activeRoom: null

  newRoomTopic: null

  isEditingTopic: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'bodyKeyDown', 'clickSender', 'fileChange',
      'onSendMessageTextCursorMove',
      'onIe9KeyUp', 'sendMessageTextKeyDown', 'sendMessageTextInput')
    @set('suggestions', [])
    App.get('eventTarget').on 'didConnect', @, @didConnect

  didInsertElement: ->
    App.set('roomsContainerView', @)

    $(window).on 'resize', @resize
    # Bind to the body so that it works regardless of where the focus is.
    $('body').on 'keydown', @bodyKeyDown
    $(document).on 'click', '.sender', @clickSender

    Ember.run.schedule 'afterRender', @, ->
      @$('.send-message-text').on 'keydown', @sendMessageTextKeyDown
      @$('.send-message-text').on 'keyup click', @onSendMessageTextCursorMove
      # `propertychange` is for IE8.
      @$('.send-message-text').on 'input propertychange', @sendMessageTextInput
      @$('.send-message-text').on 'keyup', @onIe9KeyUp if Modernizr.msie9
      @$('.send-message-file').on 'change', @fileChange
      @updateSize()
      @setFocus()

  willDestroyElement: ->
    App.set('roomsContainerView', null)

    $(window).off 'resize', @resize
    $('body').off 'keydown', @bodyKeyDown
    $(document).off 'click', '.sender', @clickSender
    @$('.send-message-text').off 'keydown', @sendMessageTextKeyDown
    @$('.send-message-text').off 'keyup click', @onSendMessageTextCursorMove
    @$('.send-message-text').off 'input propertychange', @sendMessageTextInput
    @$('.send-message-text').off 'keyup', @onIe9KeyUp if Modernizr.msie9
    @$('.send-message-file').off 'change', @fileChange

  avatarClassNames: (->
    classes = ['small-avatar']
    if ! App.get('preferences.showAvatars')
      classes.push('avatars-off')
    classes.join(' ')
  ).property('App.preferences.showAvatars')

  bodyKeyDown: (event) ->
    # No key modifiers.
    if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
      if event.which == 27 # Escape.
        # Focus on send message textarea.
        @$('.send-message-text')?.focus()

  roomChanged: (->
    # Hide autocomplete suggestions.
    @set('suggestionsShowing', false)

    # If user was editing topic, cancel it.
    @set('isEditingTopic', false)

    Ember.run.schedule 'afterRender', @, ->
      @setFocus()
  ).observes('activeRoom')

  roomAssociationsLoadedChanged: (->
    if @get('activeRoom.associationsLoaded')
      Ember.run.schedule 'afterRender', @, ->
        @setFocus()
  ).observes('activeRoom.associationsLoaded')

  isSendDisabled: Ember.computed.not('activeRoom.associationsLoaded')

  didConnect: ->
    bottom = if App.get('isFayeClientConnected')
      '0'
    else
      "#{$('.send-message-area').outerHeight()}px"

    @$('.connecting-status-bar').css
      bottom: bottom

  anyRoomTopicChanged: (->
    # A topic change can affect the height of messages list.
    Ember.run.scheduleOnce 'afterRender', @, 'updateMessagesSize'
  ).observes('rooms.@each.topic', 'isEditingTopic')

  roomsChanged: (->
    # If a room gets added later, it needs to get sized.
    Ember.run.scheduleOnce 'afterRender', @, 'updateMessagesSize'
  ).observes('rooms.@each.associationsLoaded')

  resize: _.debounce (event) ->
    Ember.run @, ->
      @updateSize()
  , 5

  activeRoomIsEncryptedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @updateSize()
  ).observes('activeRoom.isEncrypted')

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    $window = $(window)

    height = $window.height()
    messagesWidth = @messagesWidth($window)
    width = messagesWidth
    @$('.room-container').css
      width: width
      height: height

    @$('.room-name-info-container').css
      width: Math.floor(width * 0.4)
    @$('.invite-link-container').css
      width: Math.floor(width * 0.6)

    # The send message area, including textarea and send button.
    @$('.send-message-area').css
      width: width
    # The send message text input.
    textWidth = width - @$('.send-button').outerWidth() - 24
    if App.doesBrowserSupportAjaxFileUpload()
      textWidth -= @$('.send-message-file-button').outerWidth() + 4
    @$('.send-message-text').css
      width: Math.max(10, textWidth)

    # The send message file button.
    if App.doesBrowserSupportAjaxFileUpload()
      @$('.send-message-file-button').css
        right: @$('.send-button').outerWidth() + 10

    @updateMessagesSize($window, messagesWidth)

  updateMessagesSize: ($window = $(window), messagesWidth = @messagesWidth($window)) ->
    # This method needs to work for multiple message view elements.

    height = $window.height()
    height -= 20 # .room-info outerHeight() without topic.
    height -= @$('.send-message-area').outerHeight(true) ? 0

    roomMessagesViewFromElement = ($e) ->
      App._viewFromElement($e.closest('.room-messages-view'))

    isEditingTopic = @get('isEditingTopic')
    activeRoom = @get('activeRoom')
    $('.messages').each ->
      $e = $(@)
      # Don't modify the height of message lists if they don't need to be
      # changed.  That would screw up the scroll position.
      view = roomMessagesViewFromElement($e)
      view.updateSize(height, activeRoom, isEditingTopic, $e)

    # Loading more messages bar at the top.
    $loadingMoreMessages = $('.loading-more-messages')
    loadingMessagesWidth = $loadingMoreMessages.width()
    $loadingMoreMessages.css
      left: Math.round((messagesWidth - loadingMessagesWidth) / 2)

  # Returns the width of the list of messages in pixels.
  messagesWidth: ($window = $(window)) ->
    isMembersVisible = $window.width() > 700
    membersSidebarWidth = 200 # .room-members-sidebar
    width = $window.width()
    width -= ($('.rooms-sidebar').outerWidth() ? 0)
    width -= membersSidebarWidth if isMembersVisible
    width

  showSetTopicLink: (->
    @get('activeRoom.canSetTopic') && Ember.isEmpty(@get('activeRoom.topic')) &&
      ! @get('isEditingTopic')
  ).property('activeRoom.canSetTopic', 'activeRoom.topic', 'isEditingTopic')

  showTopicRow: (->
    ! Ember.isEmpty(@get('activeRoom.topic')) || @get('isEditingTopic')
  ).property('activeRoom.topic', 'isEditingTopic')

  setFocus: ->
    @$('.send-message-text')?.focus()

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
      textarea.textrange('replace', "@#{user.get('mentionName')} ")

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
          # Hide suggestions.
          @set('suggestionsShowing', false)
          event.preventDefault()
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

  showAutocomplete: ->
    # Find any @text before the cursor.
    $text = @$('.send-message-text')
    text = $text.val()
    range = $text.textrange('get')
    beforeCursorText = text[0 ... range.position]
    matches = /(?:^|\W)(@\S*)$/.exec(beforeCursorText)
    if matches
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
    else if (matches = /(?:^|\W)(\(\w*)$/.exec(beforeCursorText))
      # `(text` found; now figure out which emoticons to suggest.
      @setProperties(suggestMatchText: matches[1], textCursorPosition: range.position)
      lowerCasedInputName = matches[1].toLowerCase()
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

  fileChange: (event) ->
    Ember.run @, ->
      file = if event.target.files?
        event.target.files[0]
      else if event.target.value
        name: event.target.value.replace(/^.+\\/, '')

      if ! file?
        @clearFile()
        return

      @set('activeRoom.newMessageFile', file)

      # if Modernizr.filereader
      #   # Setup file reader.
      #   reader = new FileReader()
      #   reader.onload = (e) =>
      #     startIndex = reader.result.indexOf(',')
      #     if startIndex < 0
      #       throw new Error("I was trying to read the file base64-encoded, but I couldn't recognize the format returned from the FileReader's result")
      #     # TODO: Set image preview here.
      #     base64EncodedFile = reader.result[startIndex + 1 ..]
      #        
      #   # Actually start reading the file.
      #   reader.readAsDataURL(file)

  clearFile: ->
    @$('.send-message-file').val('')
    @set('activeRoom.newMessageFile', null)

  resetNewMessage: ->
    @set('activeRoom.newMessageText', '')
    @set('activeRoom.newMessageFile', null)

  actions:

    editTopic: ->
      @setProperties(isEditingTopic: true, newRoomTopic: @get('activeRoom.topic'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.edit-topic').focus().textrange('set') # Select all.
      return undefined

    cancelEditingTopic: ->
      @set('isEditingTopic', false)
      return undefined

    saveTopic: ->
      @set('isEditingTopic', false)
      room = @get('activeRoom')
      room.updateTopic(@get('newRoomTopic'))
      return undefined

    chooseFile: ->
      @$('.send-message-file').trigger('click')
      return undefined

    attachUrl: (url) ->
      @$('.send-message-text').textrange('replace', url)

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
        imageFile: file
        mentionedUserIds: App.Message.mentionedIdsInText(text, convo.get('members'))
      App.Message.sendNewMessage(msg)
      .then null, (e) =>
        Ember.Logger.error e
        msg.setProperties
          isError: true
          errorMessage: e?.error?.message ? e?.message ? "There was an unknown error sending this message."

      @resetNewMessage()
      @get('activeRoom.messages').pushObject(msg)

      # Get permission to show desktop notifications since it must be done in
      # response to a user event.
      @get('targetObject').send('requestNotificationPermission')

      return undefined
