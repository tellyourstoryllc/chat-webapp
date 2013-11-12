App.RoomAvatarComponent = Ember.Component.extend
  tagName: 'img'
  classNames: ['room-avatar', 'small-avatar']
  classNameBindings: ['hasAvatar::not-displayed']
  attributeBindings: ['src']

  hasAvatar: (->
    ! Ember.isEmpty(@get('room.avatarUrl'))
  ).property('room.avatarUrl')

  src: Ember.computed.alias('room.avatarUrl')
