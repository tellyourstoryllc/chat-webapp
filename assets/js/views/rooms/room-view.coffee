App.RoomsRoomView = Ember.View.extend

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize')

  didInsertElement: ->
    $(window).on 'resize', @resize
    Ember.run.schedule 'afterRender', @, 'updateSize'

  willDestroyElement: ->
    $(window).off 'resize', @resize

  resize: _.debounce ->
    Ember.run @, ->
      @updateSize()
  , 150

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    height = $(window).height()
    height -= 70
    height -= $('.navbar:first').outerHeight() ? 0
    height -= $('.send-message-area').outerHeight(true) ? 0
    @$('.messages').css
      height: height
