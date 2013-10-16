App.ApplicationView = Ember.View.extend

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'focus', 'blur')

  didInsertElement: ->
    $(window).focus @focus
    $(window).blur @blur

  focus: ->
    Ember.run @, ->
      App.set('hasFocus', true)
      @hideNotifications()

  blur: ->
    Ember.run @, ->
      App.set('hasFocus', false)

  currentlyViewingRoomChanged: (->
    @hideNotifications()
  ).observes('App.currentlyViewingRoom')

  hideNotifications: ->
    results = App.get('currentlyViewingRoom.notificationResults')
    if results?
      results.forEach (result) -> result.close()
      results.clear()
