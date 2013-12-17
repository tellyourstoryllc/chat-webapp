# Common controller methods for joining rooms.
App.JoinMixin = Ember.Mixin.create

  numMembersToShow: 10

  authState: null

  isAuthStateSignup: Ember.computed.equal('authState', 'signup')

  isAuthStateLogin: Ember.computed.equal('authState', 'login')

  alphabeticRoomMembers: (->
    (@get('room.alphabeticMembers') ? [])[0 ... @get('numMembersToShow')]
  ).property('room.alphabeticMembers.[]', 'numMembersToShow')

  moreRoomMembers: (->
    members = @get('room.alphabeticMembers')
    return null unless members?
    Math.max(0, members.get('length') - @get('numMembersToShow'))
  ).property('room.alphabeticMembers.length', 'numMembersToShow')
