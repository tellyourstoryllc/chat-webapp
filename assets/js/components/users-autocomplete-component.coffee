# Actions: didSelectSuggestion
#
# Note: we're sending the action to the parent view instead of the containing
# controller.
App.UserAutocompleteComponent = App.MessageAutocompleteComponent.extend
  classNames: ['user-autocomplete']

  showAll: true

  # Set to true to match against the full text including spaces.
  matchFullText: false

  useAtSignPrefix: true

  showCurrentUser: true

  # This is set to the text in the text input.  Callers can observe this for
  # changes.
  text: ''

  # Set to number to limit the number shown, or null for no limit.
  maxSuggestions: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onInput', 'onKeyDown', 'onIe9KeyUp', 'onCursorMove', 'elementValueDidChange')

  didInsertElement: ->
    @_super(arguments...)
    inputSelector = @get('inputSelector')
    $(document).on 'input', inputSelector, @onInput
    $(document).on 'keydown', inputSelector, @onKeyDown
    $(document).on 'keyup', inputSelector, @onIe9KeyUp if Modernizr.msie9
    $(document).on 'keyup click', inputSelector, @onCursorMove
    $(document).on 'focusOut change paste cut input', inputSelector, @elementValueDidChange

    Ember.run.schedule 'afterRender', @, ->
      @updatePosition()

  willDestroyElement: ->
    @_super(arguments...)
    inputSelector = @get('inputSelector')
    $(document).off 'input', inputSelector, @onInput
    $(document).off 'keydown', inputSelector, @onKeyDown
    $(document).off 'keyup', inputSelector, @onIe9KeyUp if Modernizr.msie9
    $(document).off 'keyup click', inputSelector, @onCursorMove
    $(document).off 'focusOut change paste cut input', inputSelector, @elementValueDidChange

  elementValueDidChange: (event) ->
    Ember.run @, ->
      @set('text', $(@get('inputSelector')).val())
      return undefined

  isShowingChanged: (->
    @updatePosition() if @get('isShowing')
  ).observes('isShowing')

  updatePosition: ->
    return unless @currentState == Ember.View.states.inDOM
    $ref = $(@get('positionRelativeToSelector') ? @get('inputSelector'))
    offset = $ref.position()
    return unless offset?
    @$().css
      top: offset.top + $ref.outerHeight()
      bottom: 'auto'

  # options
  # - mode String one of {auto|emoticons}.  If auto, uses message text.  If
  #        emoticons, ignores text and shows all emoticons.
  showAutocomplete: (options = {}) ->
    mode = options.mode ? 'auto'

    # Find any @text before the cursor.
    $text = $(@get('inputSelector'))
    text = $text.val()
    range = $text.textrange('get')
    beforeCursorText = text[0 ... range.position]
    useAtSignPrefix = @get('useAtSignPrefix')
    regex = if @get('matchFullText')
      /^([\S\s]+)$/
    else if useAtSignPrefix
      /(?:^|\W)(@\S*)$/
    else
      /(?:^|\W)(\S+)$/
    matches = regex.exec(beforeCursorText)
    if mode == 'auto' && matches
      # @text found; now figure out which names to suggest.
      matchText = matches[1]
      @setProperties(matchText: matchText, textCursorPosition: range.position)
      lowerCasedInputName = matchText.toLowerCase()
      lowerCasedInputName = lowerCasedInputName[1..] if useAtSignPrefix
      newSuggestions = []

      # @all is always first.
      if @get('showAll') && 'all'.indexOf(lowerCasedInputName) == 0
        newSuggestions.pushObject Ember.Object.create
          name: null
          value: '@all'
          isAll: true

      # Filter users.
      users = @get('users')
      currentUser = App.get('currentUser')
      filteredUsers = users.filter (u) =>
        (u.get('suggestFor').any (s) -> s.indexOf(lowerCasedInputName) == 0) &&
        (u != currentUser || @get('showCurrentUser'))

      # Move current user to the bottom of suggestions.
      index = filteredUsers.indexOf(currentUser)
      if index >= 0
        filteredUsers.removeAt(index)
        filteredUsers.pushObject(currentUser)

      # Cut off at limit.
      maxSuggestions = @get('maxSuggestions')
      if maxSuggestions?
        filteredUsers = filteredUsers.slice(0, maxSuggestions - 1)

      # Convert to suggestion object.
      userSuggestions = filteredUsers.map (u) ->
        Ember.Object.create
          name: u.get('name')
          value: "@" + u.get('mentionName')
          user: u
      newSuggestions.pushObjects(userSuggestions)
    else if mode == 'auto' && (matches = /(?:^|\W)(:\w*)$/.exec(beforeCursorText)) || mode == 'emoticons'
      # `:text` found; now figure out which emoticons to suggest.
      matchText = if mode == 'emoticons' then '' else matches[1]
      @setProperties(matchText: matchText, textCursorPosition: range.position)
      lowerCasedInputName = matchText.toLowerCase()
      newSuggestions = []

      emoticons = App.Emoticon.allArranged()
      emoticonSuggestions = emoticons.filter (e) ->
        e.get('name').toLowerCase().indexOf(lowerCasedInputName) == 0
      .map (e) ->
        Ember.Object.create
          imageUrl: e.get('imageUrl')
          value: e.get('name')
      newSuggestions.pushObjects(emoticonSuggestions)
    else
      # Nothing interesting before the cursor.
      @setProperties(suggestMatchText: null, textCursorPosition: null)
      newSuggestions = []

    if Ember.isEmpty(newSuggestions)
      # Hide instead of removing all elements so we get a nice visual effect.
      @set('isShowing', false)
    else
      @set('suggestions', newSuggestions)
      @set('isShowing', true)

  onIe9KeyUp: (event) ->
    Ember.run @, ->
      # This is to work around the fact that IE9 doesn't trigger the input event
      # when pressing backspace or delete.
      if event.which in [8, 46] # Backspace, delete.
        @onInput(event)
      return undefined

  onCursorMove: (event) ->
    Ember.run @, ->
      prevPosition = @get('textCursorPosition')
      if prevPosition?
        # We're matching autocomplete text.  If the cursor really moved, update
        # suggestions and/or hide them.
        $text = $(@get('inputSelector'))
        range = $text.textrange('get')
        if range.position != prevPosition
          @showAutocomplete()
      return undefined

  onKeyDown: (event) ->
    Ember.run @, ->
      if event.ctrlKey && ! (event.altKey || event.shiftKey || event.metaKey)
        switch event.which
          when 32 # Space.
            # Show autocomplete.
            @showAutocomplete()
            event.preventDefault()
      # The following are only for when the autocomplete suggestions are
      # showing.
      return unless @get('isShowing')
      # The suggestion popup is open.  Detect cursor movement and selection.
      switch event.which
        when 9 # Tab.
          @send('selectCurrentSuggestion')
          event.preventDefault()
          event.stopPropagation()
        when 13 # Enter.
          @send('selectCurrentSuggestion')
          event.preventDefault()
          event.stopPropagation()
        when 27 # Escape.
          if @get('isShowing')
            # Hide suggestions.
            @set('isShowing', false)
            event.preventDefault()
            event.stopPropagation()
        when 38 # Arrow up.
          @send('moveCursorUp')
          event.preventDefault()
        when 40 # Arrow down.
          @send('moveCursorDown')
          event.preventDefault()
      return undefined

  onInput: (event) ->
    Ember.run @, ->
      if @get('isShowing') && event.which in [9, 13, 38, 40]
        # User is interacting with the autocomplate view.
        return
      if event.which in [27]
        # Escape is a special case.  Always ignore it.
        return

      @showAutocomplete()
      return undefined



# View that represents each suggestion item.
App.UserAutocompleteItemView = App.MessageAutocompleteItemView.extend

  showAtMentionName: false
