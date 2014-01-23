App.AppInstallBannerComponent = Ember.Component.extend App.BaseControllerMixin,

  didInsertElement: ->
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


  actions:

    dismissAppInstallBanner: ->
      @$('.app-install-banner').addClass('hidden')
      return undefined
