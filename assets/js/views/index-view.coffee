App.IndexView = Ember.View.extend

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
    @$('.signup-form-component').addClass('expand-in')

  hideSignupModal: ->
    @$('.signup-form-component').removeClass('expand-in')
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
