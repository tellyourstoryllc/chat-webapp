App.CreateRoomModalView = Ember.View.extend

  # Text entered in create a new room dialog.
  newRoomName: ''

  isCreatingGroup: false
  isSendingAddUsersToGroup: false

  createGroupErrorMessage: null

  addUserSuggestMatchText: ''
  addUserSuggestions: null
  isAddUserSuggestionsShowing: false
  addUserSelection: null

  membersToAdd: null

  # This gets set after we create a group.
  group: null

  isCreateGroupUiDisabled: Ember.computed.any('isCreatingGroup', 'isSendingAddUsersToGroup')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown', 'onOverlayClick',
              'onAddTextBlur', 'onAddTextKeyDown', 'onAddTextInput')

    @set('membersToAdd', []) if ! @get('membersToAdd')?

    @set('newRoomName', @_defaultRoomName()) if Ember.isEmpty(@get('newRoomName'))

  didInsertElement: ->
    $('body').on 'keydown', @onBodyKeyDown
    @$('.page-overlay').on 'click', @onOverlayClick
    @$('.create-room-add-text').on 'blur', @onAddTextBlur
    @$('.create-room-add-text').on 'keydown', @onAddTextKeyDown
    @$('.create-room-add-text').on 'input', @onAddTextInput

  willDestroyElement: ->
    $('body').off 'keydown', @onBodyKeyDown
    @$('.page-overlay').off 'click', @onOverlayClick
    @$('.create-room-add-text').off 'blur', @onAddTextBlur
    @$('.create-room-add-text').off 'keydown', @onAddTextKeyDown
    @$('.create-room-add-text').off 'input', @onAddTextInput

  onBodyKeyDown: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
        if event.which == 27      # Escape
          if ! @get('isAddUserSuggestionsShowing')
            @closeModal()
            event.preventDefault()
            event.stopPropagation()

  onOverlayClick: (event) ->
    Ember.run @, ->
      # Hide the dialog if user clicked the overlay.
      if $(event.target).hasClass('page-overlay')
        @closeModal()
      return undefined

  closeModal: ->
    @get('controller').send('hideCreateRoomDialog')

  resetNewRoom: ->
    @setProperties
      group: null
      newRoomName: @_defaultRoomName()
      createGroupErrorMessage: null

  _defaultRoomName: ->
    currentUserName = App.get('currentUser.name') ? ''

    if Ember.isEmpty(currentUserName)
      "New Room"
    else
      "#{currentUserName}'s Room"

  onAddTextBlur: (event) ->
    Ember.run @, ->
      $text = @$('.create-room-add-text')
      text = $text.val()
      if ! Ember.isEmpty(text) && @isAddMemberTextValid(text)
        @send('addUsersToGroupLocally')
      return undefined

  onAddTextKeyDown: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! ( event.ctrlKey || event.altKey || event.shiftKey || event.metaKey)
        switch event.which
          when 188 # Comma.
            # If the cursor is at the end, try to add the text.
            $text = @$('.create-room-add-text')
            text = $text.val()
            range = $text.textrange('get')
            if range.position == text.length
              @send('addUsersToGroupLocally')
              event.preventDefault()
              event.stopPropagation()
          when 8 # Backspace.
            $text = @$('.create-room-add-text')
            text = $text.val()
            if text == ''
              # Text is empty and user is backspacing.  Remove the last user.
              @get('membersToAdd').popObject()
              event.preventDefault()
              event.stopPropagation()
      return undefined

  onAddTextInput: (event) ->
    Ember.run @, ->
      @updateInputSize()
      return undefined

  hasMembers: (->
    ! Ember.isEmpty(@get('membersToAdd'))
  ).property('membersToAdd.[]')

  showPlaceholder: (->
    text = @get('createRoomUserAutocompleteView.text')
    Ember.isEmpty(@get('membersToAdd')) && Ember.isEmpty(text)
  ).property('membersToAdd.[]', 'createRoomUserAutocompleteView.text')

  membersToAddChanged: (->
    Ember.run.scheduleOnce 'afterRender', @, 'updateInputSize'
  ).observes('membersToAdd.[]').on('didInsertElement')

  updateInputSize: ->
    return unless @currentState == Ember.View.states.inDOM
    # Resize text input so it fits on the last line.
    $item = @$('.add-members-list-item:last')
    if $item? && $item.size() > 0
      offset = $item.position()
      left = (offset?.left ? 0) + $item.outerWidth(true)
    else
      left = 0

    fullWidth = @$('.add-text-visual').width()
    lastLineWidth = fullWidth - left

    # Measure the width of the text.  If the text overflows, wrap to the next
    # full line.
    $text = @$('.create-room-add-text')
    text = $text.val()
    textWidth = App.TextMeasure.measure(text)

    width = if lastLineWidth < 50 || lastLineWidth < textWidth
      fullWidth
    else
      lastLineWidth

    $text.css
      width: width

  _addUsersToGroup: (group) ->
    return if @get('isSendingAddUsersToGroup')

    @set('isSendingAddUsersToGroup', true)
    data = {}
    userIds = []
    emails = []
    @get('membersToAdd').forEach (u) =>
      if u instanceof App.User
        userIds.push(u.get('id'))
      else
        emails.push(u.get('name'))
    
    if userIds.length > 0
      data.user_ids = userIds.join(',')

    if emails.length > 0
      data.emails = emails.join(',')

    api = App.get('api')
    api.ajax(api.buildURL("/groups/#{group.get('id')}/add_users"), 'POST', data: data)
    .always =>
      @set('isSendingAddUsersToGroup', false)
    .then (json) =>
      if ! json? || json.error?
        @set('createGroupErrorMessage', App.userMessageFromError(xhr))
        return false
      # Success!
      App.loadAll(json)
      # We can clear out the form now.
      @resetNewRoom()

      return true
    .catch (xhr) =>
      @set('createGroupErrorMessage', App.userMessageFromError(xhr))
      return false

  isAddMemberTextValid: (text) ->
    # Simple email-ish regex.
    /.*\S.*@\S+\.[a-zA-Z0-9\-]{2,}/.test(text)


  actions:

    didSelectAddUserSuggestion: (suggestion) ->
      # User selected a suggestion.  Expand the value into the text.
      $text = @$('.create-room-add-text')
      user = suggestion.get('user')
      if user?
        name = user.get('name') ? ''
        $text.val(name).trigger('input')
        # Move the cursor to the end of the expansion.
        $text.textrange('set', name.length + 1, 0)

        # Set selection *after* clearing text.
        @set('addUserSelection', user)

        # Add immediately.
        @send('addUsersToGroupLocally')

      # Hide suggestions.
      @set('isAddUserSuggestionsShowing', false)

      # Focus the input.
      @$('.create-room-add-text').focus()

      return undefined

    addUsersToGroupLocally: ->
      isAdding = false
      text = @$('.create-room-add-text').val()
      if (user = @get('addUserSelection'))?
        isAdding = true
        @get('membersToAdd').addObject(user)
        # Clear user selection.
        @set('addUserSelection', null)
      else if ! Ember.isEmpty(text)
        addresses = text.split(',')
        addresses.forEach (address) =>
          if @isAddMemberTextValid(address)
            isAdding = true
            obj = Ember.Object.create(name: address, _instantiatedFrom: 'text')
            @get('membersToAdd').addObject(obj)
        if ! isAdding
          @set('createGroupErrorMessage', "Must be a valid email address.")

      if isAdding
        # Clear dialog.
        @$('.create-room-add-text').val('').trigger('input')
        @set('createGroupErrorMessage', null)

      return undefined

    removeMember: (user) ->
      @get('membersToAdd').removeObject(user)
      return undefined

    createRoom: ->
      afterCreatingGroup = (wasSuccessful) =>
        # Hide the dialog.
        @closeModal() if wasSuccessful

      if (group = @get('group'))?
        # We already created a group, so continue with adding users.
        @_addUsersToGroup(group).then(afterCreatingGroup)
        return

      name = @get('newRoomName')
      if Ember.isEmpty(name)
        @set('createGroupErrorMessage', "Room Name is required.")
        return

      return if @get('isCreatingGroup')

      @setProperties(isCreatingGroup: true, createGroupErrorMessage: null)
      properties =
        name: name
      App.Group.createRecord(properties)
      .always =>
        @set('isCreatingGroup', false)
      .then (group) =>
        # Group was created successfully.
        @set('group', group)
        group.subscribeToMessages()
        # Before going to the room, prevent showing the invite dialog again.
        if ! Ember.isEmpty(@get('membersToAdd'))
          group.set('_userJustCreatedWithMembers', true)
        # Go to the room.
        @get('controller').send('goToRoom', group)
        # Add users to the group on the server.
        @_addUsersToGroup(group).then(afterCreatingGroup)

      , (xhrOrError) =>
        # Show error message.
        @set('createGroupErrorMessage', App.userMessageFromError(xhrOrError))
      .catch App.rejectionHandler

      return undefined
