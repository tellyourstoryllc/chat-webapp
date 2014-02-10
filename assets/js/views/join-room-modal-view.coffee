App.JoinRoomModalView = Ember.View.extend

  # Text entered in join room dialog.
  roomKeyText: ''

  isJoiningGroup: false

  userErrorMessage: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown', 'onOverlayClick')

  didInsertElement: ->
    $('body').on 'keydown', @onBodyKeyDown
    @$('.page-overlay').on 'click', @onOverlayClick
    Ember.run.later @, ->
      return unless @currentState == Ember.View.states.inDOM
      # This is needed so that the shake animation works.
      @$('.join-room-form').removeClass('expand-in')
    , 500

  willDestroyElement: ->
    $('body').off 'keydown', @onBodyKeyDown
    @$('.page-overlay').off 'click', @onOverlayClick

  onBodyKeyDown: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
        if event.which == 27      # Escape
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
    @get('controller').send('hideJoinRoomDialog')

  resetForm: ->
    @setProperties
      roomKeyText: ''
      userErrorMessage: null


  actions:

    joinRoom: ->
      keyText = @get('roomKeyText')
      joinCode = App.Group.parseJoinCode(keyText)
      if Ember.isEmpty(joinCode)
        @set('userErrorMessage', "Room Key is required.")
        return

      return if @get('isJoiningGroup')

      @setProperties(isJoiningGroup: true, userErrorMessage: null)
      @$('.join-room-form').removeClass('shake-side-to-side')

      App.get('api').joinGroup(joinCode)
      .always =>
        @set('isJoiningGroup', false)
      .then (group) =>
        # Group was created successfully.
        @set('group', group)
        group.subscribeToMessages()
        # Go to the room.
        @get('controller').send('goToRoom', group)
        # Hide the dialog.
        @closeModal()
        # We can clear out the form now.
        @resetForm()

      , (xhrOrError) =>
        # Show error message.
        @set('userErrorMessage', App.userMessageFromError(xhrOrError, "Sorry, we couldn't find a room with that code."))
        @$('.join-room-form').addClass('shake-side-to-side')
      .fail App.rejectionHandler

      return undefined
