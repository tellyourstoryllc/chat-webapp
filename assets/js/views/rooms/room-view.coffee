App.RoomsRoomView = Ember.View.extend

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize')

  didInsertElement: ->
    $(window).on 'resize', @resize
    Ember.run.schedule 'afterRender', @, ->
      @updateSize()
      @scrollToLastMessage()
      @activateRoomLinks()

  willDestroyElement: ->
    $(window).off 'resize', @resize

  roomsLoadedChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @activateRoomLinks()
  ).observes('controller.roomsLoaded')

  roomChanged: (->
    @scrollToLastMessage()
  ).observes('controller.model')

  messagesChanged: (->
    return unless @currentState == Ember.View.states.inDOM
    # When we append a new message, only scroll it into view if we're already at
    # the bottom.
    @scrollToLastMessage() if @isScrolledToLastMessage()
  ).observes('controller.model.messages.@each')

  resize: _.debounce ->
    Ember.run @, ->
      @updateSize()
  , 5

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    height = $(window).height()
    height -= 5
    height -= $('.navbar:first').outerHeight() ? 0
    height -= $('.room-info').outerHeight() ? 0
    height -= $('.send-message-area').outerHeight(true) ? 0
    @$('.messages').css
      height: height

    @$('.send-message-area').css
      width: @$('.messages').width() + 2
    @$('.send-message-text').css
      width: Math.max(250, @$('.messages').width() - 75)

  scrollToLastMessage: ->
    $msgs = @$('.messages')
    $msgs?.animate
      scrollTop: $msgs.get(0).scrollHeight
    , 200

  isScrolledToLastMessage: ->
    $msgs = @$('.messages')
    $msgs.height() + $msgs.prop('scrollTop') >= $msgs.prop('scrollHeight')

  activateRoomLinks: ->
    regexp = new RegExp("/#{@get('controller.model.id')}$")
    $('.room-list-item a[href]').each ->
      $link = $(@)
      if regexp.test($link.prop('href') ? '')
        $link.addClass 'active'
      else
        $link.removeClass 'active'
