#= require base-controller-mixin

App.JoinController = Ember.Controller.extend App.BaseControllerMixin,

  numMembersToShow: 10

  authState: null

  alphabeticRoomMembers: (->
    (@get('room.alphabeticMembers') ? [])[0 ... @get('numMembersToShow')]
  ).property('room.alphabeticMembers.[]', 'numMembersToShow')

  moreRoomMembers: (->
    members = @get('room.alphabeticMembers')
    return null unless members?
    Math.max(0, members.get('length') - @get('numMembersToShow'))
  ).property('room.alphabeticMembers.length', 'numMembersToShow')

  actions:

    cancelSignUp: ->
      @set('authState', null)
      return undefined

    cancelLogIn: ->
      @set('authState', null)
      return undefined
