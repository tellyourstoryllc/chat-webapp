App.IndexView = Ember.View.extend

  isShowingSignupDialog: false
  isJoinGroupSignupVisible: false
  isShowingEmailForm: false

  joinCodeToShow: Ember.computed.alias('controller.joinCodeToShow')

  room: Ember.computed.alias('controller.room')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown', 'onDownloadMacAppClick')
    # Force computed properties.
    @get('room')

  didInsertElement: ->
    App.set('indexView', @)
    $('body').on 'keydown', @onBodyKeyDown
    $('body').addClass('home-page')

    # For the desktop app landing page.
    $('body').addClass('desktop-home-page') if App.get('isMacGap')

    Ember.run.schedule 'afterRender', @, ->
      joinCode = @get('joinCodeToShow')
      if joinCode?
        App.set('roomKeyTextToShow', joinCode)
        @send('submitRoomKey', joinCode)

      if @get('controller.needsMacApp')
        @$('.download-button')?.on 'click', @onDownloadMacAppClick

  willDestroyElement: ->
    App.set('indexView', null)
    $('body').off 'keydown', @onBodyKeyDown
    $('body').removeClass('home-page')
    $('body').removeClass('desktop-home-page')

  onBodyKeyDown: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
        if event.which == 27 # Escape
          if @get('isShowingSignupDialog')
            event.preventDefault()
            @hideSignupModal()

  click: (event) ->
    if $(event.target).hasClass('page-overlay')
      event.preventDefault()
      @hideSignupModal()

  hasErrorMessage: (->
    ! Ember.isEmpty(@get('signupForm.errorMessage'))
  ).property('signupForm.errorMessage')

  showSignupModal: ->
    @set('isShowingSignupDialog', true)
    @$('.home-signup-overlay').removeClass('hidden')
    @$('.home-signup-modal').addClass('expand-in')

  hideSignupModal: ->
    @set('isShowingSignupDialog', false)
    @set('isShowingEmailForm', false)
    @$('.home-signup-modal').removeClass('expand-in')
    @$('.home-signup-overlay').addClass('hidden')

  roomChanged: (->
    room = @get('room')
    usingRoom = room?
    @set('isJoinGroupSignupVisible', usingRoom)
    if usingRoom
      @set('isShowingEmailForm', false)
  ).observes('room').on('didInsertElement')

  onDownloadMacAppClick: (event) ->
    Ember.run @, ->
      App.Analytics.trackEvent 'download', category: 'app', label: 'Mac App'
      # Do the default.
      return undefined

  actions:

    submitRoomKey: (keyText) ->
      roomKey = App.Group.parseJoinCode(keyText)
      return if Ember.isEmpty(roomKey)

      if App.get('isMacGap')
        # For desktop app, go to the join page.
        @get('controller').transitionToRoute('join', roomKey)
        return

      # Go back to first step.
      @send('goBackToAuthChoices')

      # On mobile, make sure the keyboard is hidden.
      $('.room-key-input').blur()

      @showSignupModal()
      @get('controller').send('joinRoom', roomKey)
      return undefined

    goToSignUp: ->
      # Reset room if tried to join before.
      @get('controller').send('clearJoinRoom')
      # Go back to first step.
      @send('goBackToAuthChoices')
      # Show the signup modal.
      @showSignupModal()
      return undefined

    closeSignUp: ->
      @hideSignupModal()
      return undefined

    signUpWithFacebook: ->
      @get('signupForm').send('attemptSignUpWithFacebook')
      return undefined

    signUpWithEmail: ->
      @set('isShowingEmailForm', true)
      @$('.signup-auth-choice').addClass('hidden')
      return undefined

    goBackToAuthChoices: ->
      @set('isShowingEmailForm', false)
      @$('.signup-auth-choice').removeClass('hidden')
      return undefined

    facebookDidError: (error) ->
      console.log "TODO: facebookDidError", error.message
