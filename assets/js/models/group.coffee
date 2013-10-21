#= require base-model

App.Group = App.BaseModel.extend

  # New message draft temporarily stored before sending.
  newMessageText: ''

  # New message file temporarily stored before sending.
  newMessageFile: null

  isUnread: false

  # Used to expire cache of members association.
  _membersAssociationLoaded: 0

  init: ->
    @_super(arguments...)
    @setProperties
      messages: []
      memberIds: []
      notificationResults: []

  members: (->
    @get('memberIds').map((id) -> App.User.lookup(id)).compact()
  ).property('memberIds.@each', '_membersAssociationLoaded')

  # You should call this after all the User instances have been loaded for the
  # group.
  didLoadMembers: ->
    @incrementProperty('_membersAssociationLoaded')

  cancelMessagesSubscription: ->
    @get('subscription')?.cancel()
    @set('subscription', null)

  subscribeToMessages: ->
    # If we already have a subscription, we're done.
    return if @get('subscription')?

    client = App.get('fayeClient')
    groupId = @get('id')
    if ! groupId?
      Ember.Logger.warn "I can't subscribe to messages without a group ID."
      return

    subscription = client.subscribe "/groups/#{groupId}/messages", (json) =>
      Ember.run @, ->
        Ember.Logger.log "received packet", json
        if ! json?.error? && json.object_type == 'message'
          # We received a new message.
          message = App.Message.loadRaw(json)
          @didReceiveMessage(message)
    @set('subscription', subscription)

  didReceiveMessage: (message) ->
    # Make sure the sender is loaded before displaying it.
    message.loadAssociations()
    .then (newlyLoadedMessages) =>
      # If the group and its messages were newly fetched, don't add the message
      # since it will be a dupe.
      if ! newlyLoadedMessages
        @get('messages').pushObject(message)

      fromCurrentUser = message.get('userId') == App.get('currentUser.id')
      wasMentioned = message.doesMentionUser(App.get('currentUser'))
      if ! fromCurrentUser && wasMentioned
        # The current user was mentioned.  Play sound.
        @playMentionSound()

      if ! fromCurrentUser &&
      (! App.get('hasFocus') || App.get('currentlyViewingRoom') != @)
        # Notify of new message.
        @notifyOfNewMessage(message, wasMentioned)

      if ! fromCurrentUser && App.get('currentlyViewingRoom') != @
        # Mark the room as unread.
        @set('isUnread', true)

      if ! fromCurrentUser && ! App.get('hasFocus')
        # Flash the window's titlebar.
        titleObj = Ember.Object.create
          id: message.get('groupId')
          title: message.get('title')
        App.get('pageTitlesToFlash').unshiftObject(titleObj)

    true

  playMentionSound: ->
    return unless Modernizr.audio
    audio = $('.mention-sound').get(0)
    audio.currentTime = 0 if audio.currentTime > 0
    audio.play()

  notifyOfNewMessage: (message, wasMentioned) ->
    # if ! wasMentioned
    #   # Play regular new message sound.

    # Create a desktop notification.
    notif = message.toNotification()
    title = notif.title
    delete notif.title
    result = window.notify.createNotification(title, notif)
    @get('notificationResults').pushObject(result)
    if result.nativeNotification?.addEventListener
      result.nativeNotification.addEventListener 'click', (event) ->
        # The user clicked the notification.  Go to the room.
        applicationController = App.__container__.lookup('controller:application')
        applicationController.send('goToRoom', message.get('group'))

      result.nativeNotification.addEventListener 'close', (event) ->
        # The user closed the notification.  Stop flashing that message.
        titleObjs = App.get('pageTitlesToFlash')
        groupId = message.get('groupId')
        objs = titleObjs.filterBy('id', groupId)
        titleObjs.removeObjects(objs)


App.Group.reopenClass

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  all: -> @_all

  loadRaw: (json) ->
    props = @propertiesFromRawAttrs(json)
    props.isLoaded = true

    prevInst = props.id? && @_allById[props.id]
    if prevInst?
      prevInst.setProperties(props)
      inst = prevInst
    else
      inst = @create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst

  propertiesFromRawAttrs: (json) ->
    id: App.BaseModel.coerceId(json.id)
    name: json.name
    joinUrl: json.join_url
    topic: json.topic
    memberIds: (json.member_ids ? []).map (id) -> App.BaseModel.coerceId(id)

  fetchAll: ->
    api = App.get('api')
    api.ajax(api.buildURL('/groups'), 'GET', data: {})
    .then (json) =>
      if ! json?.error?
        json = Ember.makeArray(json)
        groupObjs = json.filter (o) -> o.object_type == 'group'
        groups = groupObjs.map (g) -> App.Group.loadRaw(g)
        return groups
      else
        throw new Error(json)

  fetchById: (id) ->
    api = App.get('api')
    api.ajax(api.buildURL("/groups/#{id}"), 'GET', {})

  lookup: (id) ->
    @_allById[App.BaseModel.coerceId(id)]

  createRecord: (data) ->
    api = App.get('api')
    api.ajax(api.buildURL('/groups/create'), 'POST', data: data)
    .then (json) =>
      if json? && ! json.error?
        json = Ember.makeArray(json)
        groupAttrs = json.find (o) -> o.object_type == 'group'
        group = @loadRaw(groupAttrs)
        return group
      else
        throw json
