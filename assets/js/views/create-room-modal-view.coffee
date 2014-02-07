App.CreateRoomModalView = Ember.View.extend

  # Text entered in create a new room dialog.
  newRoomName: ''

  isCreatingGroup: false

  createGroupErrorMessage: null

  addUserSuggestMatchText: ''
  addUserSuggestions: null
  isAddUserSuggestionsShowing: false
  addUserSelection: null

  membersToAdd: null

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
          @closeModal()

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
      newRoomName: ''
      createGroupErrorMessage: null

  hasMembers: (->
    ! Ember.isEmpty(@get('membersToAdd'))
  ).property('membersToAdd.[]')

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
        @send('addUsersToGroup')

      # Hide suggestions.
      @set('isAddUserSuggestionsShowing', false)
      return undefined

    addUsersToGroup: ->
      isAdding = false
      text = @$('.create-room-add-text').val()
      if (user = @get('addUserSelection'))?
        isAdding = true
        @get('membersToAdd').addObject(user)
        # Clear user selection.
        @set('addUserSelection', null)
      else if ! Ember.isEmpty(text)
        isAdding = true
        obj = Ember.Object.create(name: text, _instantiatedFrom: 'text')
        @get('membersToAdd').addObject(obj)

      if isAdding
        # Clear dialog.
        @$('.create-room-add-text').val('').trigger('input')
        # Scroll into view.
        $e = @$('.add-members-list')
        $e.animate { scrollTop: $e.get(0).scrollHeight }, 200

      return undefined

    removeMember: (user) ->
      @get('membersToAdd').removeObject(user)
      return undefined

    createRoom: ->
      name = @get('newRoomName')
      return if Ember.isEmpty(name) || @get('isCreatingGroup')

      @setProperties(isCreatingGroup: true, createGroupErrorMessage: null)
      properties =
        name: name
      App.Group.createRecord(properties)
      .always =>
        @set('isCreatingGroup', false)
      .then (group) =>
        # Group was created successfully.
        @resetNewRoom()
        group.subscribeToMessages()
        # Go to the room.
        @get('controller').send('goToRoom', group)
        # Hide the dialog.
        @closeModal()

      , (xhrOrError) =>
        # Show error message.
        @set('createGroupErrorMessage', App.userMessageFromError(xhrOrError))
      .fail App.rejectionHandler

      return undefined
