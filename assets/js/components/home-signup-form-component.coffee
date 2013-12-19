#= require signup-form-component

# Actions: didGoBack
App.HomeSignupFormComponent = App.SignupFormComponent.extend
  showRelatedLinks: false

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

    goBack: ->
      @sendAction('didGoBack')
      return undefined
