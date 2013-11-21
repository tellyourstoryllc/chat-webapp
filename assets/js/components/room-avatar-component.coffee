App.RoomAvatarComponent = Ember.Component.extend
  tagName: 'span'
  classNames: ['room-avatar', 'small-avatar']
  classNameBindings:
    [
      'status'
      'clientType'
      'showAvatars::avatars-off' # For preference.
      'hasAvatar::not-displayed' # For groups that don't have an avatar.
      'showStatus::no-status'
    ]
  attributeBindings: ['style']

  showStatus: true

  # Set this to true to ignore the `showAvatars` preference.
  alwaysShowAvatar: false

  showAvatars: (->
    App.get('preferences.clientWeb.showAvatars') || @get('alwaysShowAvatar')
  ).property('App.preferences.clientWeb.showAvatars', 'alwaysShowAvatar')

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
