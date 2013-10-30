App.RoomsRoomView = Ember.View.extend

  group: Ember.computed.alias('controller.model')

  # Number of pixels from the top to load more messages.
  nextPageThresholdPixels: 500

  _observingMessages: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'bodyKeyDown', 'clickSender', 'fileChange',
      'scrollMessages',
      'onIe9KeyUp', 'sendMessageTextKeyDown', 'sendMessageTextInput')
    @set('suggestions', [])

  didInsertElement: ->
    # Yeah, this sucks but we have external event handlers that need this.
    App.set('currentRoomView', @)

    $(window).on 'resize', @resize
    # Bind to the body so that it works regardless of where the focus is.
    $('body').on 'keydown', @bodyKeyDown
    $(document).on 'click', '.sender', @clickSender

    Ember.run.schedule 'afterRender', @, ->
      @$('.messages').on 'scroll', @scrollMessages
      @$('.send-message-text').on 'keydown', @sendMessageTextKeyDown
      # `propertychange` is for IE8.
      @$('.send-message-text').on 'input propertychange', @sendMessageTextInput
      @$('.send-message-text').on 'keyup', @onIe9KeyUp if Modernizr.msie9
      @$('.send-message-file').on 'change', @fileChange
      @updateSize()
      @scrollToLastMessage()
      @activateRoomLinks()
      @setFocus()

  willDestroyElement: ->
    $(window).off 'resize', @resize
    $('body').off 'keydown', @bodyKeyDown
    $(document).off 'click', '.sender', @clickSender
    @$('.send-message-text').off 'keydown', @sendMessageTextKeyDown
    @$('.send-message-text').off 'input propertychange', @sendMessageTextInput
    @$('.send-message-text').off 'keyup', @onIe9KeyUp if Modernizr.msie9
    @$('.send-message-file').off 'change', @fileChange
    App.set('currentRoomView', null)

  roomsLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @activateRoomLinks()
  ).observes('controller.roomsLoaded')

  roomChanged: (->
    # Hide autocomplete suggestions.
    @set('suggestionsShowing', false)

    Ember.run.schedule 'afterRender', @, ->
      @setFocus()
  ).observes('controller.model')

  roomUsersLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @scrollToLastMessage() if @get('controller.model.usersLoaded')
  ).observes('controller.model.usersLoaded')

  messagesArrayChanged: (->
    messages = @get('controller.model.messages')
    observingMessages = @get('_observingMessages')
    if messages != observingMessages
      # Messages array changed.  Uninstall observer on old array and add to new
      # one.
      opts = willChange: 'messagesWillChange', didChange: 'messagesChanged'
      observingMessages?.removeArrayObserver(@, opts)
      messages?.addArrayObserver(@, opts)
      @set('_observingMessages', messages)

      # Track when the messages just updated.
      @set('_justChangedRooms', true)
      timer = @get('_justChangedRoomsTimer')
      if timer?
        Ember.run.cancel(timer)
      @set('_justChangedRoomsTimer', Ember.run.later(@, ->
        return if @isDestroyed
        @setProperties(_justChangedRoomsTimer: null, _justChangedRooms: false)
      , 1000))

      # Handle as if it ware a change.
      @messagesChanged(messages, 0, 0, messages.length, true)
  ).observes('controller.model.messages')

  messagesWillChange: (messages, start, removeCount, addCount) -> # Ignore.

  messagesChanged: (messages, start, removeCount, addCount, arrayObjectChanged = false) ->
    return unless @currentState == Ember.View.states.inDOM
    $messages = @$('.messages')
    isScrolledToLastMessage = @isScrolledToLastMessage()
    origScrollHeight = $messages.prop('scrollHeight')
    Ember.run.schedule 'afterRender', @, ->
      newScrollHeight = $messages.prop('scrollHeight')
      scrollHeightAdded = newScrollHeight - origScrollHeight
      # If we're adding as many as the entire length, then we're displaying the
      # page for the first time.
      if arrayObjectChanged
        # The whole messages array changed, so scroll to the bottom.  For some
        # reason, without the delay, this isn't scrolling to the very bottom.
        Ember.run.later @, 'scrollToLastMessage', 100
      else
        if scrollHeightAdded > 0 && start == 0 && addCount < messages.length
          # We've prepended some messages, so fix the scroll position so that the
          # visible portion doesn't change.
          $messages.prop('scrollTop', $messages.scrollTop() + scrollHeightAdded)
        else if isScrolledToLastMessage
          # When we append a new message to the bottom and were at the bottom,
          # scroll it into view.
          @scrollToLastMessage()

  isFayeClientConnectedChanged: (->
    bottom = if App.get('isFayeClientConnected')
      '0'
    else
      "#{$('.send-message-area').outerHeight()}px"

    @$('.connecting-status-bar').css
      bottom: bottom
  ).observes('App.isFayeClientConnected')

  scrollMessages: _.throttle (event) ->
    Ember.run @, ->
      # This prevents us from loading more while switching rooms.
      return if @get('_justChangedRooms')

      $messages = @$('.messages')
      return unless $messages?

      if $messages.scrollTop() < @get('nextPageThresholdPixels')
        @get('controller').send('loadEarlierMessages')
  , 100, leading: false

  bodyKeyDown: (event) ->
    # No key modifiers.
    if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
      if event.which == 27 # Escape.
        # Focus on send message textarea.
        @$('.send-message-text')?.focus()
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
    isMembersVisible = $window.width() > 650

    height = $window.height()
    width = $window.width()
    width -= ($('.rooms-sidebar').outerWidth() ? 0)
    width -= ($('.room-members-sidebar').outerWidth() ? 0) if isMembersVisible
    @$('.room-container').css
      width: width
      height: height

    @$('.room-members-sidebar').css
      display: if isMembersVisible then 'block' else 'none'

    height = $window.height()
    height -= $('.room-info').outerHeight() ? 0
    height -= $('.send-message-area').outerHeight(true) ? 0
    @$('.messages').css
      height: height

    # Loading more messages bar at the top.
    loadingMessagesWidth = @$('.loading-more-messages').width()
    @$('.loading-more-messages').css
      left: Math.round((width - loadingMessagesWidth) / 2)

    # The connecting status bar.
    connectingBuffer = 60
    @$('.connecting-status-bar').css
      width: width - connectingBuffer
      left: Math.floor(connectingBuffer / 2)

    # The send message area, including textarea and send button.
    @$('.send-message-area').css
      width: width
    # The send message text input.
    textWidth = width - @$('.send-button').outerWidth() - 24
    if App.doesBrowserSupportAjaxFileUpload()
      textWidth -= @$('.send-message-file-button').outerWidth() + 4
    @$('.send-message-text').css
      width: Math.max(10, textWidth)

  scrollToLastMessage: ->
    $msgs = @$('.messages')
    $msgs?.animate
      scrollTop: $msgs.get(0).scrollHeight
    , 200

  isScrolledToLastMessage: ->
    $msgs = @$('.messages')
    $msgs.height() + $msgs.prop('scrollTop') >= $msgs.prop('scrollHeight')

  # Computed property version of `isScrollToLastMessage()`.
  isScrollAnchoredToBottom: (->
    @isScrolledToLastMessage()
  ).property().volatile()

  didLoadMessageImage: ->
    @scrollToLastMessage()

  # Returns string that evaluates to the JS function to call when the image is
  # loaded.
  messageImageOnLoad: (->
    if @isScrolledToLastMessage()
      "App.onMessageImageLoad"
    else
      # When we don't want to scroll, use a no-op.
      "Ember.K"
  ).property().volatile()

  setFocus: ->
    @$('.send-message-text')?.focus()

  activateRoomLinks: ->
    regexp = new RegExp("/#{@get('controller.model.id')}$")
    $('.room-list-item a[href]').each ->
      $link = $(@)
      if regexp.test($link.prop('href') ? '')
        $link.addClass 'active'
      else
        $link.removeClass 'active'

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
      users = @get('group.arrangedMembers')
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

      @get('controller').set('newMessageFile', file)

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
    @get('controller').set('newMessageFile', null)

  actions:

    chooseFile: ->
      @$('.send-message-file').trigger('click')
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
