#= require signup-form-component

# Actions: signUpWithFacebook, logInWithRoom
App.HomeJoinGroupSignupFormComponent = App.SignupFormComponent.extend
  classNames: ['home-join-signup-form-component']
  classNameBindings: ['isElementVisible:visible']

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

    signUpWithFacebook: ->
      @sendAction('signUpWithFacebook')
      return undefined

    logInWithRoom: ->
      @sendAction('logInWithRoom')
      return undefined
