App.IndexRoute = Ember.Route.extend

  beforeModel: (transition) ->
    if App.isLoggedIn()
      @transitionTo('rooms.index')
      return

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
