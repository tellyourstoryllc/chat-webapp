App.UrlUtil = Ember.Object.extend()

App.UrlUtil.reopenClass

  # Returns the url suitable for https.
  mediaUrlToHttps: (url) ->
    # Return value unchanged if we're not on https.  Cloudfront charges
    # extra for SSL.
    return url unless /^https:/.test(location.href)

    return url unless url? && AppConfig.sslMediaHost?
    return url.replace /^http:\/\/[^\/]+/, AppConfig.sslMediaHost
