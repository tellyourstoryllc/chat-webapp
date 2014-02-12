App.CreateRoomModalView = Ember.View.extend

  # Text entered in create a new room dialog.
  newRoomName: ''

  isCreatingGroup: false
  isSendingAddUsersToGroup: false

  createGroupErrorMessage: null

  # This gets set after we create a group.
  group: null

  isCreateGroupUiDisabled: Ember.computed.any('isCreatingGroup', 'isSendingAddUsersToGroup')

  membersToAdd: Ember.computed.alias('createRoomUserMultiselectView.userSelections')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown', 'onOverlayClick')

    @set('newRoomName', @_defaultRoomName()) if Ember.isEmpty(@get('newRoomName'))

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
      newRoomName: @_defaultRoomName()
      createGroupErrorMessage: null

  _defaultRoomName: ->
    currentUserName = App.get('currentUser.name') ? ''

    if Ember.isEmpty(currentUserName)
      "New Room"
    else
      "#{currentUserName}'s Room"

  _addUsersToGroup: (group) ->
    return if @get('isSendingAddUsersToGroup')

    @set('isSendingAddUsersToGroup', true)
    data = {}
    userIds = []
    emails = []
    @get('membersToAdd').forEach (selection) =>
      u = selection.get('object')
      if u instanceof App.User
        userIds.push(u.get('id'))
      else
        emails.push(selection.get('name'))
    
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


  actions:

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
