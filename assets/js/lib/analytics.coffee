App.Analytics = Ember.Object.extend()

App.Analytics.reopenClass

  trackPageView: (url) ->
    if AppConfig.useAnalytics
      ga('send', 'pageview', url) if ga?
    else
      Ember.Logger.log "trackPageView", url

  trackEvent: (name, options = {}) ->
    if AppConfig.useAnalytics
      args = ['send', 'event']
      args.push(options.category ? 'no category')
      args.push(name) # Action.
      args.push(options.label) if options.label?
      args.push(options.value) if options.label? && options.value?
      ga(args...) if ga?
    else
      Ember.Logger.log "trackEvent", name, options
