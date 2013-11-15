App.RoomAvatarComponent = Ember.Component.extend
  tagName: 'img'
  classNames: ['room-avatar', 'small-avatar']
  classNameBindings: ['hasAvatar::not-displayed']
  attributeBindings: ['src']

  hasAvatar: (->
    ! Ember.isEmpty(@get('room.avatarUrl')) && App.get('preferences.clientWeb.showAvatars')
  ).property('room.avatarUrl', 'App.preferences.clientWeb.showAvatars')

  src: Ember.computed.alias('room.avatarUrl')
