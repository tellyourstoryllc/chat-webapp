# Cross-browser re-implementation of the page visibility API.  The parts we need
# anyway.
App.PageVisibility = Ember.Object.extend()

App.PageVisibility.reopenClass

  hiddenKey: undefined
  visibilityChangeKey: undefined
  isSupported: undefined

  initState: ->
    # Set the name of the hidden property and the change event for visibility
    if typeof document.hidden isnt "undefined" # Opera 12.10 and Firefox 18 and later support
      @hiddenKey = "hidden"
      @visibilityChangeKey = "visibilitychange"
    else if typeof document.mozHidden isnt "undefined"
      @hiddenKey = "mozHidden"
      @visibilityChangeKey = "mozvisibilitychange"
    else if typeof document.msHidden isnt "undefined"
      @hiddenKey = "msHidden"
      @visibilityChangeKey = "msvisibilitychange"
    else if typeof document.webkitHidden isnt "undefined"
      @hiddenKey = "webkitHidden"
      @visibilityChangeKey = "webkitvisibilitychange"

    @isSupported = !! @hiddenKey

  hidden: ->
    @hiddenKey && document[@hiddenKey]

App.PageVisibility.initState()
