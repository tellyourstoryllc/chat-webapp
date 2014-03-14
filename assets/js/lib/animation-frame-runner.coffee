App.AnimationFrameRunner = Ember.Object.extend

  nextFrameCallbacks: null
  hasRequestedAnimationFrame: false

  init: ->
    @set('nextFrameCallbacks', []) if ! @get('nextFrameCallbacks')?

  # Runs the given function during the next animation frame.  If this is called
  # multiple times, all given functions will be run during the same next frame.
  #
  # All functions will be called within an Ember run loop, so you shouldn't need
  # to make one yourself.
  nextFrame: (fn) ->
    @get('nextFrameCallbacks').pushObject(fn)
    if ! @get('hasRequestedAnimationFrame')
      handler = @_wrappedWithRunLoop(@handleAnimFrame)
      window.requestAnimFrame(handler)
      @set('hasRequestedAnimationFrame', true)

  _wrappedWithRunLoop: (fn) ->
    => Ember.run @, fn

  handleAnimFrame: ->
    @set('hasRequestedAnimationFrame', false)

    fns = @get('nextFrameCallbacks')
    # Switch to a new array so that if callbacks try to add more to our queue,
    # they get run next frame, not now.
    @set('nextFrameCallbacks', [])
    fn() for fn in fns

    undefined

# shim layer with setTimeout fallback
# http://www.paulirish.com/2011/requestanimationframe-for-smart-animating/
window.requestAnimFrame = (->
  window.requestAnimationFrame       ||
  window.webkitRequestAnimationFrame ||
  window.mozRequestAnimationFrame    ||
  ( callback ) ->
    window.setTimeout(callback, 1000 / 60)
)()
