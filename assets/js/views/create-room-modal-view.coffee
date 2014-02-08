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
    _.bindAll(@, 'onBodyKeyDown', 'onOverlayClick')
    @set('membersToAdd', []) if ! @get('membersToAdd')?

  didInsertElement: ->
    $('body').on 'keydown', @onBodyKeyDown
    @$('.page-overlay').on 'click', @onOverlayClick

  willDestroyElement: ->
    $('body').off 'keydown', @onBodyKeyDown
    @$('.page-overlay').off 'click', @onOverlayClick

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
      newRoomName: ''
      createGroupErrorMessage: null

  hasMembers: (->
    ! Ember.isEmpty(@get('membersToAdd'))
  ).property('membersToAdd.[]')

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
    .fail (xhr) =>
      @set('createGroupErrorMessage', App.userMessageFromError(xhr))
      return false

  isAddMemberUiDisabled: (->
    isValid = @isAddMemberTextValid(@get('createRoomUserAutocompleteView.text'))
    @get('isCreateGroupUiDisabled') || ! isValid
  ).property('isCreateGroupUiDisabled', 'createRoomUserAutocompleteView.text')

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
        if @isAddMemberTextValid(text)
          isAdding = true
          obj = Ember.Object.create(name: text, _instantiatedFrom: 'text')
          @get('membersToAdd').addObject(obj)
        else
          @set('createGroupErrorMessage', "Must be a valid email address.")

      if isAdding
        # Clear dialog.
        @$('.create-room-add-text').val('').trigger('input')
        @set('createGroupErrorMessage', null)
        # Scroll into view.
        $e = @$('.add-members-list')
        $e.animate { scrollTop: $e.get(0).scrollHeight }, 200

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
      .fail App.rejectionHandler

      return undefined
