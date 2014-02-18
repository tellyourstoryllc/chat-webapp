App.BaseControllerMixin = Ember.Mixin.create

  init: ->
    @_super(arguments...)
    # Force computed properties.
    @get('isLoggedIn')

  isLoggedIn: (->
    App.isLoggedIn()
  ).property('App._isLoggedIn')

  isNotLoggedIn: Ember.computed.not('isLoggedIn')

  # Note: Ember.computed.alias doesn't work here.
  currentUser: (->
    App.get('currentUser')
  ).property('App.currentUser')

  isMobilePlatform: Ember.computed.any('isAppleIos', 'isAndroid')

  isAppleIos: (->
    Modernizr.appleios
  ).property()

  isAndroid: (->
    Modernizr.android
  ).property()

  # When this is supported, we can read files locally and show image previews,
  # for example.
  doesBrowserSupportFileReader: (->
    Modernizr.filereader
  ).property()

  # Returns true if the browser can both select the file and upload it via AJAX.
  doesBrowserSupportAjaxFileUpload: (->
    App.doesBrowserSupportAjaxFileUpload()
  ).property()

  doesBrowserSupportRangeInput: (->
    Modernizr.inputtypes.range
  ).property()
