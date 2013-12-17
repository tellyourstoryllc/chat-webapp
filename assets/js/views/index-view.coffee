App.IndexView = Ember.View.extend

  didInsertElement: ->
    App.set('indexView', @)
    $('body').addClass('home-page')

  willDestroyElement: ->
    App.set('indexView', null)
    $('body').removeClass('home-page')

  showSignupModal: ->
    @$('.home-signup-overlay').removeClass('hidden')
    @$('.signup-form-component').addClass('expand-in')

  hideSignupModal: ->
    @$('.signup-form-component').removeClass('expand-in')
    @$('.home-signup-overlay').addClass('hidden')

  actions:

    submitRoomKey: ->
      console.log "TODO"
      return undefined

    goToSignUp: ->
      # Show the signup modal.
      @showSignupModal()
      return undefined
