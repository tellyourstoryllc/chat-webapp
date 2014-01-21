#= require signup-form-component

# Actions: signUpWithFacebook, logInWithRoom
App.RoomJoinGroupSignupFormComponent = App.SignupFormComponent.extend App.AutoFillSignupMixin,
  classNames: ['room-join-group-signup-form-component']

  showRelatedLinks: false
  showFacebookChoice: true
  shouldRequirePassword: false

  userErrorMessageDidChange: (->
    Ember.run.schedule 'afterRender', @, ->
      # Run later so that it's actually inserted into the DOM and the CSS can
      # transition.
      Ember.run.later @, ->
        # Transition the error message in.
        if Ember.isEmpty(@get('errorMessage'))
          @$('.alert').removeClass('visible')
        else
          @$('.alert').addClass('visible')
      , 50
  ).observes('errorMessage')

  actions:

    logInWithRoom: ->
      @sendAction('logInWithRoom')
      return undefined
