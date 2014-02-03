App.ChromePermissionBarMixin = Ember.Mixin.create

  windowHeight: null
  isChromePermissionBarVisible: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onResize')

  didInsertElement: ->
    @_super(arguments...)
    @set('windowHeight', $(window).height())
    $(window).on 'resize', @onResize

  willDestroyElement: ->
    @_super(arguments...)
    $(window).off 'resize', @onResize

  onResize: _.debounce (event) ->
    Ember.run @, ->
      return unless @isChromeBrowser()

      # Make sure the translucent gray covers the whole viewport.
      $window = $(window)
      $('.chrome-permission-bar-callout').css
        width: $window.width()
        height: $window.height()

      # Detect when Chrome permission bar pops down or up.  Yeah... this is
      # pretty hacky.
      oldWindowHeight = @get('windowHeight')
      newWindowHeight = $(window).height()
      deltaHeight = newWindowHeight - oldWindowHeight
      # Be conservative about showing the callout, but don't bother checking the
      # flag when hiding it.
      if App.get('isRequestingNotificationPermission') && -40 < deltaHeight < -30
        @set('isChromePermissionBarVisible', true)
      else if 30 < deltaHeight < 40
        @set('isChromePermissionBarVisible', false)

      @set('windowHeight', newWindowHeight)

      return undefined
  , 300

  isChromeBrowser: ->
    str = navigator.userAgent.toLowerCase()
    /Chrome|Chromium|CriOS/i.test(str)

  isChromePermissionBarVisibleChanged: (->
    if @get('isChromePermissionBarVisible')
      $('.chrome-permission-bar-callout').addClass('visible')
    else
      $('.chrome-permission-bar-callout').removeClass('visible')
  ).observes('isChromePermissionBarVisible')

  actions:

    # This provides a way to close the cover over the entire window if the
    # Chrome bar detection is bogus for some reason.
    dismissChromePermissionCallout: ->
      @set('isChromePermissionBarVisible', false)
      return undefined
