#= require base-controller-mixin

App.ApplicationController = Ember.Controller.extend App.BaseControllerMixin,

  isIdleChanged: (->
    App.publishClientStatus()
  ).observes('App.isIdle')

  showAvatarsChanged: (->
    if App.get('preferences.clientWeb.showAvatars')
      $('.small-avatar').removeClass('avatars-off')
    else
      $('.small-avatar').addClass('avatars-off')
  ).observes('App.preferences.clientWeb.showAvatars')
