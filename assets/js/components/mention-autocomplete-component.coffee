# Actions: didSelectSuggestion
#
# Note: we're sending the action to the parent view instead of the containing
# controller.
App.MentionAutocompleteComponent = Ember.Component.extend
  classNameBindings: [':mention-autocomplete', 'isShowing::hidden']

  # Caller should bind this to collection of objects with name and value
  # properties.  Value is what the item expands to when selected.
  suggestions: null

  cursorIndex: 0

  # Caller should bind this to the matched text (without the @).
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
App.MentionAutocompleteItemView = Ember.View.extend
  classNameBindings: [':mention-autocomplete-item', 'isActive:active']

  autocompleteView: Ember.computed.alias('parentView')

  collectionView: Ember.computed.alias('_parentView')

  isActive: (->
    @get('contentIndex') == @get('autocompleteView.cursorIndex')
  ).property('contentIndex', 'autocompleteView.cursorIndex')

  itemDisplay: (->
    escape = Ember.Handlebars.Utils.escapeExpression
    suggestion = @get('content')

    value = escape(suggestion.get('value'))
    matchText = @get('autocompleteView.matchText')

    # Highlight the matched text in the @name.
    if matchText?.length && value.toLowerCase().indexOf(matchText.toLowerCase()) == 0
      value = "<strong>" + value[0 ... matchText.length] + "</strong>" + value[matchText.length..]

    # TODO: highlight matched text in name if it matches there.
    name = suggestion.get('name')
    if name?
      display = escape(name) + " (#{value})"
    else if suggestion.get('imageUrl')
      img = "<img class='emoticon' src='#{escape(suggestion.get('imageUrl'))}'>"
      display = img + " #{value}"
    else
      display = value

    display.htmlSafe()
  ).property('content.name', 'content.value', 'autocompleteView.matchText')

  click: ->
    @get('autocompleteView').send('selectSuggestion', @get('content'))
