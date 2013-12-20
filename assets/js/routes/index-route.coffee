App.IndexRoute = Ember.Route.extend

  afterModel: (model, transition) ->
    if App.isLoggedIn()
      @transitionTo('rooms.index')
      return

  setupController: (controller, model) ->
    @_super(arguments...)

    # If we transitioned from the join page, we may have a join code waiting to
    # be used.
    joinCode = App.get('joinCodeToShow')
    # Consume this so it doesn't stick forever.
    App.set('joinCodeToShow', null) if joinCode?
    # Always set on the controller so that it gets cleared out properly.
    controller.set('joinCodeToShow', joinCode)

  renderTemplate: (controller, model) ->
    @_super(arguments...)
    # If we're on iOS, render the mobile install.
    if Modernizr.appleios
      @render 'mobile-install',
        into: 'application'
        outlet: 'modal'

  actions:

    goToSignUp: ->
      indexView = App.get('indexView')
      if indexView?
        # Note: IndexView should not pass this up the hierarchy back to here.
        # TODO: not sure if this is async or not, so not sure the best way to
        # prevent infinite looping.
        indexView.send('goToSignUp')
      else
        # Bubble up.
        return true
      return undefined

    goBackToAuthChoices: ->
      App.get('indexView')?.send('goBackToAuthChoices')
      return undefined

    facebookDidError: (error) ->
      App.get('indexView')?.send('facebookDidError', error)
