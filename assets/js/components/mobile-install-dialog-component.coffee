App.MobileInstallDialogComponent = Ember.Component.extend

  classNames: ['mobile-install-dialog']

  joinCode: null

  actions:

    installMobileApp: ->
      Ember.Logger.error "TODO: installMobileApp"
      return undefined

    launchMobileApp: ->
      joinCode = @get('joinCode')
      if joinCode?
        App.attemptToOpenMobileApp("/group/join_code/#{joinCode}")
      else
        App.attemptToOpenMobileApp('/')
      return undefined
