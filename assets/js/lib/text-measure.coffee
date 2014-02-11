# Module for measure text width.
App.TextMeasure = Ember.Object.extend()

App.TextMeasure.reopenClass

  _element: null

  # Given text, measures the width in pixels.  Use the `css` option to specify
  # the font and other style options to get the correct width.
  measure: ->
    @elementWithText(arguments...).width()

  # Given text, returns jquery object of single element with the text.
  #
  # Note: The element is re-used to reduce DOM memory use, so if you need to
  # measure it, do it immediately, not asynchronously.
  elementWithText: (text, options = {}) ->
    e = @_element
    if ! e?
      e = @_element = document.createElement('div')
      justCreated = true

    $e = $(e)

    if justCreated
      $e.addClass('_App_TextMeasure')

    cssProps =
      position: 'absolute'
      visibility: 'hidden'
      margin: 0
      padding: 0
      'white-space': 'nowrap'
    _.extend(cssProps, options.css) if options.css?
    $e.css cssProps
    $e.text(text)

    if justCreated
      $e.appendTo(document.body)

    $e
