App.InviteRoute = Ember.Route.extend

  model: (params, transition) ->
    params.invite_token

  afterModel: (model, transition) ->
    if ! App.isLoggedIn() && ! App.get('isLoggingIn')
      if model? && model.length >= 9
        # Attempt to log in using the invite token.
        App.logInFromInviteToken(model, renderErrorMessage: false)
        .catch (xhrOrError) =>
          # Logging in treating it as an invite_token failed.  Treat it as a group
          # id since the iOS app uses this.
          App.Group.fetchAndLoadSingle(model)
          .then (group) =>
            if group
              # Make sure the join code is shown on mobile install.
              App.set('continueToRoomWhenReady', group)
      else
        # Treat it as a group id since the iOS app uses this.
        App.Group.fetchAndLoadSingle(model)
        .then (group) =>
          if group
            # Make sure the join code is shown on mobile install.
            App.set('continueToRoomWhenReady', group)
        , (xhrOrError) =>
          # Logging in treating it as an invite_token failed.  Attempt to log in
          # using the invite token.
          App.logInFromInviteToken(model, renderErrorMessage: false)

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

  actions:

    didDismissMobileInstallDialog: ->
      @transitionTo('index')
      return undefined
