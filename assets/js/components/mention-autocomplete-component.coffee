# Actions: didSelectSuggestion
#
# Note: we're sending the action to the parent view instead of the containing
# controller.
App.MentionAutocompleteComponent = Ember.Component.extend
  classNameBindings: [':mention-autocomplete', 'isShowing::hidden']

  # Caller should bind this to collection of objects with name and value
  # properties.  Value is what the item expands to when selected.  If value is
  # null (in the case of @all), name is used as fallback.
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
    suggestion = @get('content')
    # TODO: highlight matched text in name if we start matching by last name
    display = "#{Ember.Handlebars.Utils.escapeExpression(suggestion.get('name'))}"
    matchText = @get('autocompleteView.matchText')

    value = suggestion.get('value')
    if value?
      # Highlight the matched text in the @name.
      value = Ember.Handlebars.Utils.escapeExpression(suggestion.get('value'))
      if matchText?.length && value.toLowerCase().indexOf(matchText.toLowerCase()) == 0
        value = "<strong>" + value[0 ... matchText.length] + "</strong>" + value[matchText.length..]
      display += " (#{value})"

    display.htmlSafe()
  ).property('content.name', 'content.value', 'autocompleteView.matchText')

  click: ->
    @get('autocompleteView').send('selectSuggestion', @get('content'))
