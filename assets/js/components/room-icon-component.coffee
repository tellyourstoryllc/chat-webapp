App.RoomIconComponent = Ember.Component.extend
  tagName: 'span'
  classNames: ['room-icon']
  classNameBindings: ['hasStatus:status-icon', 'computedStatus']

  hasStatus: Ember.computed.alias('room.hasStatusIcon')

  computedStatus: (->
    room = @get('room')
    if room.get('hasStatusIcon')
      room.get('computedStatus')
    else
      null
  ).property('room.hasStatusIcon', 'room.computedStatus')
