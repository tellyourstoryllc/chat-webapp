App.RoomsRoomView = Ember.View.extend

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize', 'bodyKeyDown', 'fileChange')

  didInsertElement: ->
    # Yeah, this sucks but we have external event handlers that need this.
    App.set('currentRoomView', @)

    $(window).on 'resize', @resize
    # Bind to the body so that it works regardless of where the focus is.
    $('body').on 'keydown', @bodyKeyDown

    Ember.run.schedule 'afterRender', @, ->
      @$('.send-message-file').on 'change', @fileChange
      @updateSize()
      @scrollToLastMessage()
      @activateRoomLinks()
      @setFocus()

  willDestroyElement: ->
    $(window).off 'resize', @resize
    $('body').off 'keydown', @bodyKeyDown
    @$('.send-message-file').off 'change', @fileChange
    App.set('currentRoomView', null)

  roomsLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @activateRoomLinks()
  ).observes('controller.roomsLoaded')

  roomChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @scrollToLastMessage()
      @setFocus()
  ).observes('controller.model')

  messagesChanged: (->
    return unless @currentState == Ember.View.states.inDOM
    # When we append a new message, only scroll it into view if we're already at
    # the bottom.
    @scrollToLastMessage() if @isScrolledToLastMessage()
  ).observes('controller.model.messages.@each')

  isFayeClientConnectedChanged: (->
    bottom = if App.get('isFayeClientConnected')
      '0'
    else
      "#{$('.send-message-area').outerHeight()}px"

    @$('.connecting-status-bar').css
      bottom: bottom
  ).observes('App.isFayeClientConnected')

  bodyKeyDown: (event) ->
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
