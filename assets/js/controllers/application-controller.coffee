#= require base-controller-mixin

App.ApplicationController = Ember.Controller.extend App.BaseControllerMixin,

  isIdleChanged: (->
    App.publishClientStatus()
  ).observes('App.isIdle')
