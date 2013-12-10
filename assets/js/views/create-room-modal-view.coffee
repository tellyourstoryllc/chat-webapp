App.CreateRoomModalView = Ember.View.extend

  # Text entered in create a new room dialog.
  newRoomName: ''

  createGroupErrorMessage: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onOverlayClick')

  didInsertElement: ->
    @$('.page-overlay').on 'click', @onOverlayClick

  willDestroyElement: ->
    @$('.page-overlay').off 'click', @onOverlayClick

  onOverlayClick: (event) ->
    Ember.run @, ->
      # Hide the dialog if user clicked the overlay.
      if $(event.target).hasClass('page-overlay')
        @closeModal()

  closeModal: ->
    @get('controller').send('hideCreateRoomDialog')

  resetNewRoom: ->
    @setProperties
      newRoomName: ''
      createGroupErrorMessage: null

  actions:

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
