#= require base-model

App.Preferences = App.BaseModel.extend

  init: ->
    @_super(arguments...)
    @set('clientWeb', Ember.Object.create()) if ! @get('clientWeb')?



App.Preferences.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  clientPrefsDefaults:
    playSoundOnMessageReceive: true
    showNotificationOnMessageReceive: true
    playSoundOnOneToOneMessageReceive: true
    showNotificationOnOneToOneMessageReceive: true
    playSoundOnMention: true
    showNotificationOnMention: true
    showJoinLeaveMessages: true
    # The number of minutes of inactivity after which the client is considered
    # idle on this device.
    showIdleAfterMinutes: 5
    showAvatars: true
    showWallpaper: true
    notificationVolume: 100

  propertiesFromRawAttrs: (json) ->
    props =
      id: @coerceId(json.id)
      serverMentionEmail: json.server_mention_email
      serverOneToOneEmail: json.server_one_to_one_email

    # Parse client preferences as JSON.
    clientWebProps = if json.client_web? then JSON.parse(json.client_web) else null
    # Don't overwrite the nested object if one wasn't given.
    props.clientWeb = Ember.Object.create(clientWebProps) if clientWebProps?

    props

  coerceValueFromStorage: (key, value) ->
    # Parse an int but never return NaN.
    parseIntWithDefault = (str, defaultVal) ->
      n = parseInt(str)
      n = defaultVal if _.isNaN(n)
      n

    if key == 'notificationVolume'
      # Integer in the range [0, 100].
      n = parseIntWithDefault(value, 100)
      return Math.min(100, Math.max(0, n))

    if key == 'showIdleAfterMinutes'
      # Integer in the range [1, 480].
      n = parseIntWithDefault(value, 5)
      return Math.min(480, Math.max(1, n))

    # All other values are booleans.
    ! (value in ['0', 'false'])
