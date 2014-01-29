App.Analytics = Ember.Object.extend()

App.Analytics.reopenClass

  trackPageView: (url) ->
    if AppConfig.useAnalytics
      _gaq.push(['_trackPageview', url]) if _gaq?
    else
      Ember.Logger.log "trackPageView", url

  trackEvent: (name, options = {}) ->
    if AppConfig.useAnalytics
      args = ['_trackEvent']
      args.push(options.category ? 'no category')
      args.push(name)
      args.push(options.label) if options.label?
      args.push(options.value) if options.label? && options.value?
      _gaq.push(args) if _gaq?
    else
      Ember.Logger.log "trackEvent", name, options
