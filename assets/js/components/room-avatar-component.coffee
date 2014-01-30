App.RoomAvatarComponent = Ember.Component.extend
  tagName: 'span'
  classNames: ['room-avatar', 'small-avatar']
  classNameBindings:
    [
      'status'
      'clientType'
      'showAvatar::blank-avatar' # To show status dot only, all the time.
      'showAvatars::avatars-off' # For preference.
      'showStatus::no-status'
      'isGroup:group'
      'alwaysShowAvatar:always-show-avatar'
    ]
  attributeBindings: ['style']

  showStatus: true

  showAvatar: true

  # Set this to true to ignore the `showAvatars` preference.
  alwaysShowAvatar: false

  showAvatars: (->
    App.get('preferences.clientWeb.showAvatars')
  ).property('App.preferences.clientWeb.showAvatars')

  status: (->
    room = @get('room')
    return null unless room?
    if room.get('hasStatusIcon')
      room.get('status')
    else
      null
  ).property('room.hasStatusIcon', 'room.status')

  clientType: (->
    room = @get('room')
    return null unless room?
    if room.get('hasStatusIcon')
      room.get('clientType')
    else
      null
  ).property('room.hasStatusIcon', 'room.clientType')

  isGroup: (->
    @get('room') instanceof App.Group
  ).property('room')

  style: (->
    url = @get('room.avatarUrl')
    return null unless url?
    "background-image: url('#{url}')"
  ).property('room.avatarUrl')
