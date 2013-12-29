# Actions: didDismissMobileInstallDialog
App.MobileInstallDialogComponent = Ember.Component.extend App.BaseControllerMixin,

  classNames: ['mobile-install-dialog']

  joinCode: null

  actions:

    launchMobileApp: ->
      joinCode = @get('joinCode')
      if joinCode?
        App.attemptToOpenMobileApp("/group/join_code/#{joinCode}")
      else
        App.attemptToOpenMobileApp('/')
      return undefined

    dismissMobileInstallDialog: ->
      @sendAction('didDismissMobileInstallDialog')
      return undefined
