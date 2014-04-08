App.ChatRoute = Ember.Route.extend

  model: (params, transition) ->
    params.group_id

  setupController: (controller, model) ->
    @_super(arguments...)

    # Track in MixPanel.
    App.get('api').logEvent(event_name: 'clicked_invite_link')
    .finally =>
      # Redirect after tracking.

      # Attempt to open the app.
      protocol = App.Util.currentPlatformLaunchAppProtocol()
      if protocol
        loadedAt = +new Date
        # Launch the app.
        window.location = '' + protocol + '://'
        # If the app isn't installed, fall back to opening the App Store.
        window.setTimeout =>
          if +new Date - loadedAt < 2000
            # If we're still here, open the app store.
            url = App.Util.currentPlatformInstallAppUrl()
            url ?= '/'
            window.location = url
        , 100
      else if (url = App.Util.currentPlatformInstallAppUrl())?
        App.Util.redirect(url)
      else
        # If all else fails, go home.
        @replaceWith('index')
