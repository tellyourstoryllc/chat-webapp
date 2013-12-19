#= require base-controller-mixin

App.JoinController = Ember.Controller.extend App.BaseControllerMixin, App.JoinMixin,

  room: null

  actions:

    cancelSignUp: ->
      @set('authState', null)
      return undefined

    cancelLogIn: ->
      @set('authState', null)
      return undefined
