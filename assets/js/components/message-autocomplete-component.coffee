# Actions: didSelectSuggestion
#
# Note: we're sending the action to the parent view instead of the containing
# controller.
App.MessageAutocompleteComponent = Ember.Component.extend
  classNameBindings: [':autocomplete', 'isShowing::hidden']

  # Caller should bind this to collection of objects with name and value
  # properties.  Value is what the item expands to when selected.
  suggestions: null

  cursorIndex: 0

  # Caller should bind this to the matched text (with the @).
  matchText: null

  suggestionsChanged: (->
    @set('cursorIndex', 0)
  ).observes('suggestions.@each')

  actions:

    moveCursorDown: ->
      if @get('cursorIndex') < @get('suggestions.length') - 1
        @incrementProperty('cursorIndex')
      return undefined

    moveCursorUp: ->
      if @get('cursorIndex') > 0
        @decrementProperty('cursorIndex')
      return undefined

    selectCurrentSuggestion: ->
      suggestion = @get('suggestions').objectAt(@get('cursorIndex'))
      @send('selectSuggestion', suggestion) if suggestion?
      return undefined

    selectSuggestion: (suggestion) ->
      # Trigger the action on the containing view, instead of the controller,
      # the way `@sendAction()` would.
      #
      # @sendAction('didSelectSuggestion', suggestion)
      actionName = @get('didSelectSuggestion')
      if actionName?
        @get('parentView').send(actionName, suggestion)

      # Close the autocomplete popup.
      @set('isShowing', false)

      return undefined


# View that represents each suggestion item.
App.MessageAutocompleteItemView = Ember.View.extend
  classNameBindings: [':autocomplete-item', 'isActive:active', 'isAll:all-item']

  autocompleteView: Ember.computed.alias('parentView')

  isAll: Ember.computed.bool('content.isAll')

  isActive: (->
    @get('contentIndex') == @get('autocompleteView.cursorIndex')
  ).property('contentIndex', 'autocompleteView.cursorIndex')

  itemDisplay: (->
    escape = Ember.Handlebars.Utils.escapeExpression
    suggestion = @get('content')

    value = suggestion.get('value')
    matchText = @get('autocompleteView.matchText')

    # Highlight the matched text in the @name.
    if matchText?.length && value.toLowerCase().indexOf(matchText.toLowerCase()) == 0
      escapedValue = "<strong>" + escape(value[0 ... matchText.length]) + "</strong>" + escape(value[matchText.length..])
      highlightFound = true
    else
      escapedValue = escape(value)

    name = suggestion.get('name')
    if name?
      escapedName = escape(name)
      # Highlight matched text in name if it matches there.
      suggestFor = suggestion.get('user.suggestFor')
      if ! highlightFound && matchText?.length && suggestFor
        # Strip off the @ sign.
        matchText = matchText[1..] if matchText[0] == '@'
        # Find the word that we matched.  We do it this way to prevent
        # highlighting in the middle of words.
        word = suggestFor.find (word) -> word.indexOf(matchText) == 0
        # Find that word in the name.
        index = name.toLowerCase().indexOf(word)
        if index >= 0
          escapedName = escape(name[0 ... index]) + "<strong>" +
            escape(name[index ... index + matchText.length]) + "</strong>" +
            escape(name[index + matchText.length ..])
      display = escapedName + " (#{escapedValue})"
      user = suggestion.get('user')
      if user?
        display = "<span class='room-avatar blank-avatar #{user.get('status')}'></span> " + display
    else if suggestion.get('imageUrl')
      img = "<img class='emoticon' src='#{escape(suggestion.get('imageUrl'))}'>"
      display = img + " #{escapedValue}"
    else
      display = escapedValue

    display.htmlSafe()
  # This also depends on suggestFor.@each, but that shouldn't change and I don't
  # want to add any more observers than are needed for performance.
  ).property('content.name', 'content.value', 'content.imageUrl',
             'content.user.status',
             'autocompleteView.matchText')

  click: ->
    @get('autocompleteView').send('selectSuggestion', @get('content'))
