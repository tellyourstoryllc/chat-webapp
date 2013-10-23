App.RoomsView = Ember.View.extend

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'resize')

  didInsertElement: ->
    $(window).on 'resize', @resize

    Ember.run.schedule 'afterRender', @, ->
      @updateSize()

  willDestroyElement: ->
    $(window).off 'resize', @resize

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
