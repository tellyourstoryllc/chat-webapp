# Actions: didDismissMobileInstallDialog
App.MobileInstallDialogComponent = Ember.Component.extend App.BaseControllerMixin,

  classNames: ['mobile-install-dialog']

  joinCode: null

  hiddenTimes: 0

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onTouchEnd')

  didInsertElement: ->
    @$('.hidden-continue').on 'touchend', @onTouchEnd

  willDestroyElement: ->
    @$('.hidden-continue').off 'touchend', @onTouchEnd

  onTouchEnd: (event) ->
    Ember.run @, ->
      @incrementProperty('hiddenTimes')
      times = @get('hiddenTimes') ? 0
      if times > 0 && times % 3 == 0
        @sendAction('didDismissMobileInstallDialog')
      return undefined


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
