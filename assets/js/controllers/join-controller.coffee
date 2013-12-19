#= require base-controller-mixin

App.JoinController = Ember.Controller.extend App.BaseControllerMixin, App.JoinMixin,

  numMembersToShow: 7 # 4 on first row, 3 +more on second row.

  room: null

  actions:

    cancelSignUp: ->
      @set('authState', null)
      return undefined

    cancelLogIn: ->
      @set('authState', null)
      return undefined
