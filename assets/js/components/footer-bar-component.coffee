App.FooterBarComponent = Ember.Component.extend App.BaseControllerMixin,

  showAppLinks: false

  areAppLinksVisible: (->
    showAppLinks = @get('showAppLinks')
    if Ember.typeOf(showAppLinks) == 'string'
      showAppLinks == 'mobile-only' && (Modernizr.appleios || Modernizr.android)
    else
      # Treat as boolean.
      showAppLinks
  ).property('showAppLinks')
