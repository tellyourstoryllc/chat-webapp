# Actions: didSelectSuggestion, didExpandSuggestion, selectionWasAdded, selectionWasRemoved
App.MultiselectUserAutocompleteComponent = Ember.Component.extend
  classNames: ['multiselect-user-autocomplete-component']

  #########################################################
  # Input

  # Set to true to send actions to the view instead of the controller.
  sendActionsTargetIsView: false

  # Caller should bind this to the list of all users used as autocomplete
  # suggestions.
  users: null

  # Set to number to limit the number of autocomplete suggestions shown, or null
  # for no limit.
  maxSuggestions: 10

  # Set to true to display the current (logged in) user in suggestions.
  showCurrentUser: false

  # Placeholder text to display in UI when empty.
  placeholderText: null

  #########################################################
  # Input/Output

  areSuggestionsShowing: false

  #########################################################
  # Output

  # Collection of users selected.
  userSelections: null

  userErrorMessage: null

  #########################################################
  # Internal

  text: ''

  prevInputWidth: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onAddTextBlur', 'onAddTextKeyDown', 'onAddTextInput')
    @set('userSelections', []) if ! @get('userSelections')?

  didInsertElement: ->
    @_super(arguments...)
    @$('.text-input').on 'blur', @onAddTextBlur
    @$('.text-input').on 'keydown', @onAddTextKeyDown
    @$('.text-input').on 'input', @onAddTextInput

  willDestroyElement: ->
    @_super(arguments...)
    @$('.text-input').off 'blur', @onAddTextBlur
    @$('.text-input').off 'keydown', @onAddTextKeyDown
    @$('.text-input').off 'input', @onAddTextInput

  showPlaceholder: (->
    text = @get('text')
    Ember.isEmpty(@get('userSelections')) && Ember.isEmpty(text)
  ).property('userSelections.[]', 'text')

  placeholder: (->
    if @get('showPlaceholder')
      @get('placeholderText')
    else
      ''
  ).property('showPlaceholder', 'placeholderText')

  userSelectionsChanged: (->
    Ember.run.scheduleOnce 'afterRender', @, 'updateInputSize'
  ).observes('userSelections.[]').on('didInsertElement')

  onAddTextBlur: (event) ->
    Ember.run @, ->
      @_super?(event)
      $text = @$('.text-input')
      text = $text.val()
      if ! Ember.isEmpty(text) && @isAddItemTextValid(text)
        @send('addSelection')
      return undefined

  onAddTextKeyDown: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! ( event.ctrlKey || event.altKey || event.shiftKey || event.metaKey)
        switch event.which
          when 188 # Comma.
            # If the cursor is at the end, try to add the text.
            $text = @$('.text-input')
            text = $text.val()
            range = $text.textrange('get')
            if range.position == text.length
              if @get('areSuggestionsShowing')
                # Select suggestion if it's showing.
                @get('userAutocompleteView').send('selectCurrentSuggestion')
              else
                # If not showing suggestions, it's probably an email address.
                # Just add whatever's in the text input.
                @send('addSelection')
              event.preventDefault()
              event.stopPropagation()
          when 8 # Backspace.
            $text = @$('.text-input')
            text = $text.val()
            if text == ''
              # Text is empty and user is backspacing.  Remove the last user.
              @get('userSelections').popObject()
              event.preventDefault()
              event.stopPropagation()
      return undefined

  onAddTextInput: (event) ->
    Ember.run @, ->
      @updateInputSize()
      return undefined

  updateInputSize: ->
    return unless @currentState == Ember.View.states.inDOM
    # Resize text input so it fits on the last line.
    $item = @$('.selection-list-item:last')
    if $item? && $item.size() > 0
      offset = $item.position()
      left = (offset?.left ? 0) + $item.outerWidth(true)
    else
      left = 0

    fullWidth = @$('.visual-text-ui').width()
    lastLineWidth = fullWidth - left

    # Measure the width of the text.  If the text overflows, wrap to the next
    # full line.
    $text = @$('.text-input')
    text = $text.val()
    textWidth = App.TextMeasure.measure(text, css: { font: $text.css('font') })

    width = if lastLineWidth < 50 || lastLineWidth < textWidth
      fullWidth
    else
      lastLineWidth

    $text.css
      width: width

    # Resizing could move expand or contract the input box by a line, and the
    # autocomplete suggestions may need to move.
    prevInputWidth = @get('prevInputWidth')
    if ! prevInputWidth? || prevInputWidth != width
      @get('userAutocompleteView').updatePosition()
    @set('prevInputWidth', width)

  userErrorMessageChanged: (->
    # Size of the error message can move the text box.
    Ember.run.schedule 'afterRender', @, ->
      @get('userAutocompleteView').updatePosition()
  ).observes('userErrorMessage')

  # TODO: validation should be specified by the caller.
  isAddItemTextValid: (text) ->
    # Simple email-ish regex.
    /.*\S.*@\S+\.[a-zA-Z0-9\-]{2,}/.test(text)

  _sendAction: (action, context = undefined) ->
    # Trigger the action on the containing view, instead of the controller,
    # the way `@sendAction()` would.
    if @get('sendActionsTargetIsView')
      actionName = @get(action)
      if actionName?
        @get('parentView').send(actionName, context)
    else
      @sendAction(action, context)


  actions:

    didSelectSuggestion: (suggestion) ->
      # Relay action.
      @_sendAction('didSelectSuggestion', suggestion)

      # User selected a suggestion.  Expand the value into the text.
      $text = @$('.text-input')
      user = suggestion.get('user')
      if user?
        name = user.get('name') ? ''
        $text.val(name).trigger('input')
        # Move the cursor to the end of the expansion.
        $text.textrange('set', name.length + 1, 0)

        # Set selection *after* clearing text.
        @set('addUserSelection', user)

        # Add immediately.
        @send('addSelection')

      # Hide suggestions.
      @set('areSuggestionsShowing', false)

      # Focus the input.
      @$('.text-input').focus()

      @_sendAction('didExpandSuggestion', suggestion)

      return undefined

    addSelection: ->
      isAdding = false
      additions = []
      text = @$('.text-input').val()
      if (user = @get('addUserSelection'))?
        isAdding = true
        @get('userSelections').addObject(user)
        additions.pushObject(user)
        # Clear user selection.
        @set('addUserSelection', null)
      else if ! Ember.isEmpty(text)
        addresses = text.split(',')
        addresses.forEach (address) =>
          if @isAddItemTextValid(address)
            isAdding = true
            obj = Ember.Object.create(name: address, _instantiatedFrom: 'text')
            @get('userSelections').addObject(obj)
            additions.pushObject(obj)
        if ! isAdding
          @set('userErrorMessage', "Must be a valid email address.")

      if isAdding
        # Clear dialog.
        @$('.text-input').val('').trigger('input')
        @set('userErrorMessage', null)

        # Notify caller.
        @_sendAction('selectionWasAdded', additions)

      return undefined

    removeSelection: (user) ->
      @get('userSelections').removeObject(user)
      @_sendAction('selectionWasRemoved', user)
      return undefined
