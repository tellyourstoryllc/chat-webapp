# Actions: didDismissMobileInstallDialog
App.MobileInstallDialogComponent = Ember.Component.extend App.BaseControllerMixin,

  classNames: ['mobile-install-dialog']

  joinCode: null

  showWebAppOption: false

  # Set to true to change the text displayed in the UI.
  hasMessagesWaiting: false

  hiddenTimes: 0

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onTouchEnd', 'onInstallAppClick')

  didInsertElement: ->
    $('body').addClass('with-mobile-dialog')
    @$('.hidden-continue').on 'touchend', @onTouchEnd
    @$('.app-store-link').on 'click', @onInstallAppClick
    # Run later so that images can hopefully load.
    Ember.run.later @, ->
      # If the setting is saved, auto-launch the mobile app.
      if window.localStorage.getItem('autoLaunchApp') in ['1', 'true']
        @send('launchMobileApp')
    , 50

  willDestroyElement: ->
    @$('.hidden-continue').off 'touchend', @onTouchEnd
    @$('.app-store-link').off 'click', @onInstallAppClick
    $('body').removeClass('with-mobile-dialog')

  onTouchEnd: (event) ->
    Ember.run @, ->
      @incrementProperty('hiddenTimes')
      times = @get('hiddenTimes') ? 0
      if times > 0 && times % 3 == 0
        @sendAction('didDismissMobileInstallDialog')
      return undefined

  onInstallAppClick: (event) ->
    Ember.run @, ->
      # When user clicks install app, forget auto launch setting.
      @clearAutoLaunchSetting()
      return undefined

  clearAutoLaunchSetting: ->
    window.localStorage.removeItem('autoLaunchApp')


  actions:

    launchMobileApp: ->
      joinCode = @get('joinCode')
      if joinCode?
        App.attemptToOpenMobileApp("/group/join_code/#{joinCode}")
      else
        App.attemptToOpenMobileApp('/')

      # Save so that we automatically open next time.
      window.localStorage.setItem('autoLaunchApp', '1')

      return undefined

    dismissMobileInstallDialog: ->
      # When user clicks dismiss, don't auto launch the app anymore.
      @clearAutoLaunchSetting()

      @sendAction('didDismissMobileInstallDialog')
      return undefined
