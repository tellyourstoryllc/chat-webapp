App.RoomIconComponent = Ember.Component.extend
  tagName: 'span'
  classNames: ['room-icon']
  classNameBindings: ['hasStatus:status-icon', 'status', 'clientType']

  hasStatus: Ember.computed.alias('room.hasStatusIcon')

  status: (->
    room = @get('room')
    if room.get('hasStatusIcon')
      room.get('computedStatus')
    else
      null
  ).property('room.hasStatusIcon', 'room.status')

  clientType: (->
    room = @get('room')
    if room.get('hasStatusIcon')
      room.get('clientType')
    else
      null
  ).property('room.hasStatusIcon', 'room.clientType')
