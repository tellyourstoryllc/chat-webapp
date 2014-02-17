App.InviteRoute = Ember.Route.extend

  model: (params, transition) ->
    params.invite_token

  afterModel: (model, transition) ->
    if ! App.isLoggedIn() && ! App.get('isLoggingIn')
      # Attempt to log in using the invite token.
      App.logInFromInviteToken(model)
    # Redirect to /login.  Never render a template on this route.
    @replaceWith('login')
    return undefined
