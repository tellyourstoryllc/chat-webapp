App.RoomIconComponent = Ember.Component.extend
  tagName: 'span'
  classNames: ['room-icon']
  classNameBindings: ['hasStatus:status-dot', 'computedStatus']

  hasStatus: (->
    @get('room') instanceof App.OneToOne
  ).property('room')

  computedStatus: (->
    room = @get('room')
    if room instanceof App.OneToOne
      room.get('otherUser.computedStatus')
    else
      null
  ).property('room.otherUser.computedStatus')
