App.Analytics = Ember.Object.extend()

App.Analytics.reopenClass

  trackPageView: (url) ->
    if AppConfig.useAnalytics
      _gaq.push(['_trackPageview', url]) if _gaq?
    else
      Ember.Logger.log "trackPageView", url
