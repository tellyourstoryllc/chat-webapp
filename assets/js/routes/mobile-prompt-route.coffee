App.MobilePromptRoute = Ember.Route.extend

  actions:

    didDismissMobileInstallDialog: ->
      @transitionTo('index')
      return undefined
