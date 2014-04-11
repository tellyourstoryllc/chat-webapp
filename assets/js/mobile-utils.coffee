# Util functions used outside the Ember app.
window.MobileUtils = MobileUtils =

  isIos: !! navigator.userAgent.match(/iPad|iPhone|iPod/i)

  isAndroid: !! navigator.userAgent.match(/Android/i)

  currentPlatformInstallAppUrl: ->
    if MobileUtils.isIos && AppConfig.iosAppInstallUrl?
      AppConfig.iosAppInstallUrl
    else if MobileUtils.isAndroid && AppConfig.androidAppInstallUrl?
      AppConfig.androidAppInstallUrl

  currentPlatformLaunchAppProtocol: ->
    if MobileUtils.isIos && AppConfig.iosAppLaunchProtocol?
      AppConfig.iosAppLaunchProtocol
    else if MobileUtils.isAndroid && AppConfig.androidAppLaunchProtocol?
      AppConfig.androidAppLaunchProtocol

  redirect: (url) ->
    try
      window.location.replace(url)
    catch e
      window.location.href = url

  # Given a route url path, returns it with any unique tokens substituted with
  # XXX.  This allows Google Analytics tracking to treat them all as the same
  # URL.
  #
  # Note: ***If you change this, also change `App.Router.stripAppTokensFromUrl()`***
  stripAppTokensFromUrl: (url) ->
    if /^\/i\/[^\/\?]+/.test(url)
      '/i/XXX'
    else if /^\/view\/[^\/\?]+/.test(url)
      '/view/XXX'
    else if /^\/chat\/[^\/\?]+/.test(url)
      '/chat/XXX'
    else
      url
