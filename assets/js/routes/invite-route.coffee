App.InviteRoute = Ember.Route.extend

  model: (params, transition) ->
    params.invite_token

  afterModel: (model, transition) ->
    if ! App.isLoggedIn() && ! App.get('isLoggingIn')
      # Attempt to log in using the invite token.
      App.logInFromInviteToken(model)

    if Modernizr.appleios || Modernizr.android
      # Show the install app prompt.
      @replaceWith('mobile-prompt')
      # Stay there after logging in.
      App.set('continueTransitionArgs', ['mobile-prompt'])
    else
      # Never render a template on this route.  Going to /signup since it's
      # probably a new user.
      @replaceWith('signup')
    return undefined
