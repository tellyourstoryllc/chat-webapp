App.RoomAvatarComponent = Ember.Component.extend
  tagName: 'span'
  classNames: ['room-avatar', 'small-avatar']
  classNameBindings: ['status', 'clientType', 'showAvatars::avatars-off', 'hasAvatar::not-displayed']
  attributeBindings: ['style']

  showAvatars: (->
    App.get('preferences.clientWeb.showAvatars')
  ).property('App.preferences.clientWeb.showAvatars')

  status: (->
    room = @get('room')
    if room.get('hasStatusIcon')
      room.get('status')
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

  hasAvatar: (->
    @get('room.hasStatusIcon')
  ).property('room.hasStatusIcon')

  style: (->
    url = @get('room.avatarUrl')
    return null unless url?
    "background-image: url('#{url}')"
  ).property('room.avatarUrl')
