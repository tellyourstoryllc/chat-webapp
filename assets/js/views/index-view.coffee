App.IndexView = Ember.View.extend

  isShowingSignupDialog: false
  isShowingEmailForm: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown')

  didInsertElement: ->
    App.set('indexView', @)
    $('body').on 'keydown', @onBodyKeyDown
    $('body').addClass('home-page')

  willDestroyElement: ->
    App.set('indexView', null)
    $('body').off 'keydown', @onBodyKeyDown
    $('body').removeClass('home-page')

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

  showSignupModal: ->
    @set('isShowingSignupDialog', true)
    @$('.home-signup-overlay').removeClass('hidden')
    @$('.home-signup-modal').addClass('expand-in')

  hideSignupModal: ->
    @set('isShowingSignupDialog', false)
    @set('isShowingEmailForm', false)
    @$('.home-signup-modal').removeClass('expand-in')
    @$('.home-signup-overlay').addClass('hidden')

  actions:

    submitRoomKey: ->
      keyText = @$('.room-key-input').val()
      roomKey = App.Group.parseJoinCode(keyText)
      return if Ember.isEmpty(roomKey)

      # Go back to first step.
      @send('goBackToAuthChoices')

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
      console.log "TODO signUpWithFacebook"
      @get('signupForm').send('attemptSignUpWithFacebook')
      return undefined

    signUpWithEmail: ->
      @set('isShowingEmailForm', true)
      @$('.signup-auth-choice').addClass('hidden')
      @$('.signup-form-component').addClass('visible')
      return undefined

    goBackToAuthChoices: ->
      @set('isShowingEmailForm', false)
      @$('.signup-auth-choice').removeClass('hidden')
      @$('.signup-form-component').removeClass('visible')
      return undefined
