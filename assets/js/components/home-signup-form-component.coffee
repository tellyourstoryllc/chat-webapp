#= require signup-form-component

# Actions: didGoBack
App.HomeSignupFormComponent = App.SignupFormComponent.extend
  showRelatedLinks: false

  actions:

    goBack: ->
      @sendAction('didGoBack')
      return undefined
