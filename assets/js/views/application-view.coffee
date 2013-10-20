App.ApplicationView = Ember.View.extend

  _pageTitleFlashTimer: null
  _isShowingPageTitleFlash: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'focus', 'blur')

  didInsertElement: ->
    $(window).focus @focus
    $(window).blur @blur

  focus: ->
    Ember.run @, ->
      App.set('hasFocus', true)
      App.get('pageTitlesToFlash').clear()
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

  pageTitlesToFlashChanged: (->
    if Ember.isEmpty(App.get('pageTitlesToFlash'))
      @stopFlashingPageTitle()
    else
      @startFlashingPageTitle()
  ).observes('App.pageTitlesToFlash.@each')

  startFlashingPageTitle: ->
    timer = @get('_pageTitleFlashTimer')
    if ! timer?
      @_flashPageTitle()

  stopFlashingPageTitle: ->
    timer = @get('_pageTitleFlashTimer')
    if timer?
      Ember.run.cancel(timer)
      @set('_pageTitleFlashTimer', null)
    @_removePageTitleFlash()

  _flashPageTitle: ->
    if @get('_isShowingPageTitleFlash')
      @_removePageTitleFlash()
    else
      @_addPageTitleFlash()
    @set('_pageTitleFlashTimer', Ember.run.later(@, '_flashPageTitle', 1000))

  _removePageTitleFlash: ->
    $(document).attr('title', App.get('title'))
    @set('_isShowingPageTitleFlash', false)

  _addPageTitleFlash: ->
    titleObj = App.get('pageTitlesToFlash')[0]
    $(document).attr('title', "#{titleObj.get('title')} | #{App.get('title')}")
    @set('_isShowingPageTitleFlash', true)
