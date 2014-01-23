App.AppInstallBannerComponent = Ember.Component.extend App.BaseControllerMixin,

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onInstallAppClick')

  didInsertElement: ->
    @$('.install-app-link').on 'click', @onInstallAppClick

    # Run later so that images can hopefully load.
    Ember.run.later @, ->
      # If the setting is saved, auto-launch the mobile app.
      if window.localStorage.getItem('autoLaunchApp') in ['1', 'true']
        @send('launchMobileApp')
    , 50

    # Show the app install banner after a delay.
    Ember.run.later @, ->
      return unless @currentState == Ember.View.states.inDOM
      $forPlatform = @$('.for-platform')
      if $forPlatform?
        platform = if Modernizr.iphone
          'iPhone'
        else if Modernizr.ipad
          'iPad'
        else if Modernizr.ipod
          'iPod'
        if platform?
          $forPlatform.text("for #{platform}")
      @$('.app-install-banner')?.removeClass('temporarily-hidden')
    , 2500

  willDestroyElement: ->
    @$('.install-app-link').off 'click', @onInstallAppClick

  onInstallAppClick: (event) ->
    Ember.run @, ->
      # When user clicks install app, forget auto launch setting.
      @clearAutoLaunchSetting()
      return undefined

  clearAutoLaunchSetting: ->
    window.localStorage.removeItem('autoLaunchApp')


  actions:

    dismissAppInstallBanner: ->
      # When user clicks dismiss, don't auto launch the app anymore.
      @clearAutoLaunchSetting()

      @$('.app-install-banner').addClass('hidden')
      return undefined

    launchMobileApp: ->
      joinCode = @get('joinCode')
      if joinCode?
        App.attemptToOpenMobileApp("/group/join_code/#{joinCode}")
      else
        App.attemptToOpenMobileApp('/')

      # Save so that we automatically open next time.
      window.localStorage.setItem('autoLaunchApp', '1')

      return undefined
