App.IndexView = Ember.View.extend

  isShowingEmailForm: false

  didInsertElement: ->
    App.set('indexView', @)
    $('body').addClass('home-page')

  willDestroyElement: ->
    App.set('indexView', null)
    $('body').removeClass('home-page')

  click: (event) ->
    if $(event.target).hasClass('page-overlay')
      event.preventDefault()
      @hideSignupModal()

  showSignupModal: ->
    @$('.home-signup-overlay').removeClass('hidden')
    @$('.home-signup-modal').addClass('expand-in')

  hideSignupModal: ->
    @$('.home-signup-modal').removeClass('expand-in')
    @$('.home-signup-overlay').addClass('hidden')

  actions:

    submitRoomKey: ->
      keyText = @$('.room-key-input').val()
      roomKey = App.Group.parseJoinCode(keyText)
      return if Ember.isEmpty(roomKey)
      @showSignupModal()
      @get('controller').send('joinRoom', roomKey)
      return undefined

    goToSignUp: ->
      # Reset room if tried to join before.
      @get('controller').send('clearJoinRoom')
      # Show the signup modal.
      @showSignupModal()
      return undefined

    closeSignUp: ->
      @hideSignupModal()
      return undefined

    signUpWithFacebook: ->
      console.log "TODO signUpWithFacebook"
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
