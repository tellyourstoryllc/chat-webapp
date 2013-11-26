# View for the scrollable messages of a specific room.  Since there are many
# messages and rendering them is expensive, this view is created even when the
# user isn't viewing the associated room.  It is shown and hidden when the user
# switches to the room.
App.RoomMessagesView = Ember.View.extend
  classNames: ['room-messages-view']

  # Caller should bind this to the room.
  room: null

  # Caller should bind this to all the rooms.
  rooms: null

  # Number of pixels from the top to load more messages.
  nextPageThresholdPixels: 500

  # Messages array that we're currently observing.
  _observingMessages: null

  init: ->
    @_super(arguments...)

  didInsertElement: ->
    @$('.messages').on 'scroll', @onScrollMessages
    Ember.run.schedule 'afterRender', @, ->
      @scrollToLastMessage(true)

  willDestroyElement: ->

  hasAttachment: (->
    @get('room.newMessageFile')?
  ).property('room.newMessageFile')

  attachmentName: (->
    # Make sure to always show something.
    name = @get('room.newMessageFile.name')
    name = '(file attached)' if Ember.isEmpty(name)
    name
  ).property('room.newMessageFile.name')

  newMessageFileChanged: (->
    # Make sure preview is supported.
    return unless Modernizr.filereader

    file = @get('room.newMessageFile')
    previousFileUrl = @get('attachmentPreviewUrl')
    if ! file?
      if previousFileUrl?
        # Delay so the UI can transition.
        Ember.run.later @, ->
          @set('attachmentPreviewUrl', null)
        , 400 # This should match the transition-duration.
      return

    canPreview = file?.type in ['image/png', 'image/gif', 'image/jpeg', 'image/vnd.microsoft.icon']
    if ! canPreview
      @set('attachmentPreviewUrl', null)
      return

    # Setup file reader.
    reader = new FileReader()
    reader.onload = (e) =>
      startIndex = reader.result.indexOf(',')
      if startIndex < 0
        throw new Error("I was trying to read the file base64-encoded, but I couldn't recognize the format returned from the FileReader's result")
      # Set image preview.
      base64EncodedFile = reader.result[startIndex + 1 ..]
      @set('attachmentPreviewUrl', "data:image/png;base64," + base64EncodedFile)

    # Actually start reading the file.
    reader.readAsDataURL(file)
  ).observes('room.newMessageFile')

  # $messages should be the jQuery object of .messages element.
  updateSize: (height, activeRoom, isEditingTopic, $messages) ->
    return unless @currentState == Ember.View.states.inDOM
    room = @get('room')
    hasVisibleTopic = room == activeRoom && isEditingTopic || ! Ember.isEmpty(room.get('topic'))
    messagesHeight = height
    messagesHeight -= 23 if hasVisibleTopic # .topic-cell outerHeight()
    isScrolledToLastMessage = @isScrolledToLastMessage()
    $messages.css
      height: messagesHeight

    if isScrolledToLastMessage
      @scrollToLastMessage(false)

  roomWillChange: (->
    room = @get('room')
    App.get('roomMessagesViews').remove(room) if room?
  ).observesBefore('room')

  roomChanged: (->
    room = @get('room')
    # This is used in the rare situations where we need to get to this view
    # instance when we only have a reference to the room.
    App.get('roomMessagesViews').set(room, @) if room?
  ).observes('room').on('init')

  roomAssociationsLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @scrollToLastMessage(false) if @get('room.associationsLoaded')
  ).observes('room.associationsLoaded')

  messagesArrayChanged: (->
    messages = @get('room.messages')
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
  ).observes('room.messages').on('init')

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
        Ember.run.later @, 'scrollToLastMessage', true, 100
      else
        if scrollHeightAdded > 0 && start == 0 && addCount < messages.length
          # We've prepended some messages, so fix the scroll position so that the
          # visible portion doesn't change.
          $messages.prop('scrollTop', $messages.scrollTop() + scrollHeightAdded)
        else if isScrolledToLastMessage
          # When we append a new message to the bottom and were at the bottom,
          # scroll it into view.
          @scrollToLastMessage(true)

  isCurrentlyViewingRoom: (->
    App.get('currentlyViewingRoom') == @get('room')
  ).property('App.currentlyViewingRoom', 'room')

  isRoomBeforeCursor: (->
    rooms = @get('rooms')
    return false unless rooms?
    index = rooms.indexOf(@get('room'))
    cursorIndex = rooms.indexOf(App.get('currentlyViewingRoom'))
    return false if index < 0 || cursorIndex < 0
    index < cursorIndex
  ).property('rooms.@each', 'room', 'App.currentlyViewingRoom')

  # Raw event handler called in the context of the DOM element.  We need to do
  # it this way since there are multiple instances visible at the same time.
  onScrollMessages: (event) ->
    view = App._viewFromElement($(@).closest('.room-messages-view'))
    view?.scrollMessages(arguments...)

  scrollMessages: _.throttle (event) ->
    Ember.run @, ->
      # This prevents us from loading more while switching rooms.
      return if @get('_justChangedRooms')

      $messages = @$('.messages')
      return unless $messages?

      if $messages.scrollTop() < @get('nextPageThresholdPixels')
        @get('room').fetchAndLoadEarlierMessages()
  , 100, leading: false

  scrollToLastMessage: (animate) ->
    $msgs = @$('.messages')
    return unless $msgs?
    props = scrollTop: $msgs.get(0).scrollHeight
    if animate && @get('isCurrentlyViewingRoom')
      $msgs.animate props, 200
    else
      $msgs.prop(props)

  isScrolledToLastMessage: ->
    return true if @currentState != Ember.View.states.inDOM
    $msgs = @$('.messages')
    $msgs.height() + $msgs.prop('scrollTop') >= $msgs.prop('scrollHeight')

  # Computed property version of `isScrollToLastMessage()`.
  isScrollAnchoredToBottom: (->
    @isScrolledToLastMessage()
  ).property().volatile()

  didLoadMessageImage: (element, objectType) ->
    if objectType in ['image', 'audio', 'video']
      # Just loaded a regular image, audio, or video element.
      @scrollToLastMessage(false)
    else
      $msgs = @$('.messages')
      return unless $msgs?
      # Assume the emoticon loaded above the scrolled-into-view content, so
      # scroll down the difference between a line of text and the height of the
      # loaded image.
      baseLineHeight = 20
      imageHeight = $(element).height()
      diff = Math.max(0, imageHeight - baseLineHeight)
      if diff > 0
        $msgs.prop('scrollTop', $msgs.prop('scrollTop') + diff)

  # Returns string that evaluates to the JS function to call when the image is
  # loaded.
  messageImageOnLoad: (->
    if @isScrolledToLastMessage()
      "App.onMessageImageLoad"
    else
      # When we don't want to scroll, use a no-op.
      "Ember.K"
  ).property().volatile()
