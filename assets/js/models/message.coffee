#= require base-model

App.Message = App.BaseModel.extend

  # Message text when the message was created locally.  This is never sent over
  # the wire without first going through the processing pipe.
  localText: null

  # Error message to diplay to the user.
  errorMessage: null

  conversation: Ember.computed.any('group', 'oneToOne')

  group: (->
    id = @get('groupId')
    return null unless id?
    App.Group.lookup(id)
  ).property('groupId')

  oneToOne: (->
    id = @get('oneToOneId')
    return null unless id?
    App.OneToOne.lookup(id)
  ).property('oneToOneId')

  user: (->
    App.User.lookup(@get('userId'))
  ).property('userId', 'conversation._membersAssociationLoaded')

  mentionedUsers: (->
    @get('mentionedUserIds').map (id) -> App.User.lookup(id)
  ).property('mentionedUserIds')

  doesMentionUser: (user) ->
    mentionedUserIds = @get('mentionedUserIds')
    return true if mentionedUserIds.any (id) -> id == App.Message.mentionAllId
    userId = user.get('id')
    return false unless userId?
    mentionedUserIds.any (id) -> id == userId

  title: (->
    parts = [@get('user.name') ? "User #{@get('userId')}"]

    convo = @get('conversation')
    roomName = if convo?
      convo.get('name')
    else if @get('groupId')?
      "Room #{@get('groupId')}"
    else if @get('oneToOneId')?
      "1-on-1 with User #{@get('oneToOneId')}"

    parts.join(' | ')
  ).property('user.name', 'conversation.name')

  # Use this property whenever displaying message text to the user.
  userFacingText: (->
    localText = @get('localText')
    return localText if localText?

    @get('conversation').processIncomingMessageText(@, @get('text'))
  ).property('localText', 'text')

  # Use this property whenever sending message text over the wire.
  networkFacingText: (->
    text = @get('text')
    return text if text?

    @get('conversation').processOutgoingMessageText(@, @get('localText'))
  ).property('localText', 'text')

  # This is the html text with emoticons and mentions.
  body: (->
    # For some reason, this is getting triggered on rooms that haven't been
    # loaded yet.  Since this is a fairly expensive computation, just exit
    # without doing anything since the result will be bogus anyway.
    return null if ! @get('conversation.usersLoaded')

    # When the current user sends a message, show his or her text prior to
    # processing.
    userFacingText = @get('userFacingText') ? ''

    escape = Ember.Handlebars.Utils.escapeExpression

    # Link to URLs.
    linkedText = linkify userFacingText,
      callback: (chunk, href, options) =>
        # No link, just text.
        return escape(chunk) if ! href?

        display = chunk
        # Truncate before escaping.
        if display.length > 100
          attrs = " title='#{escape(display)}'"
          display = "#{display[0...100]}..."

        # Escape the display.
        escapedDisplay = escape(display)

        # Allow soft line break after slashes in a URL.  Must be after escaping
        # so that our wbr tags don't get lost.
        escapedDisplay = escapedDisplay.replace /\//g, '/<wbr>'

        "<a href='" + escape(href) + "'" + attrs + " target='_blank'>" + escapedDisplay + '</a>'

    # Mentions.
    currentUser = App.get('currentUser')
    convo = @get('conversation')
    groupMembers = convo.get('members')
    evaledText = linkedText.replace /@(\w+)/g, (fullMatch, name) ->
      user = App.User.userMentionedInGroup(name, groupMembers)
      isAll = /^all$/i.test(name)
      if user? || isAll
        classNames = ['mention']
        classNames.push('you') if user == currentUser || isAll
        "<span class='#{classNames.join(' ')}'>#{fullMatch}</span>"
      else
        fullMatch

    # Emoticons.
    groupId = @get('groupId')
    evaledText = App.Emoticon.all().reduce (str, emoticon) ->
      regexp = new RegExp(App.Util.escapeRegexp(emoticon.get('name')), 'g')
      imageHtml = "<img class='emoticon' src='#{emoticon.get('imageUrl')}'" +
                  " title='#{escape(emoticon.get('name'))}'" +
                  " onload='App.onMessageImageLoad(&quot;#{escape(groupId)}&quot;, this, true);'>"
      str.replace regexp, imageHtml
    , evaledText

    evaledText.htmlSafe()
  # Note: We omit conversation members' names from dependent keys since we don't
  # care about updating mentions when a user changes his/her name or a new user
  # joins or leaves the room.
  ).property('App.emoticonsVersion', 'userFacingText', 'conversation.usersLoaded')

  isSentByCurrentUser: (->
    userId = @get('userId')
    userId? && userId == App.get('currentUser.id')
  ).property('userId', 'App.currentUser.id')

  sentByClassName: (->
    userId = @get('userId')
    return null unless userId?
    "sent-by-#{userId}"
  # Note: userId should never change, so not using it as dependent key for
  # performance.
  ).property()

  fetchAndLoadAssociations: ->
    @get('conversation').fetchAndLoadAssociations()

  notificationTag: (->
    convo = @get('conversation')
    "#{convo.constructor}:#{convo.get('id')}"
  ).property('conversation.id')

  toNotification: ->
    text = @get('userFacingText')
    if Ember.isEmpty(text) && @get('imageUrl')?
      text = "(file attached)"

    # TODO: icon field.
    tag: @get('notificationTag')
    title: @get('title')
    body: text
    icon: {}


App.Message.reopenClass

  # ID representing @all mention.  Yes, a string to match the type of other IDs.
  mentionAllId: '-1'

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  # Identity map of Messages by client ID (GUID).
  _allByClientId: {}

  propertiesFromRawAttrs: (json) ->
    api = App.get('api')
    mentionedUserIds = if Ember.isArray(json.mentioned_user_ids)
      json.mentioned_user_ids
    else
      (json.mentioned_user_ids ? '').split(/,/)

    # Parse JSON.
    clientMetadata = if json.client_metadata
      JSON.parse(json.client_metadata)
    else
      {}
    # Extract the client ID.
    if Ember.typeOf(clientMetadata) == 'string'
      # If it's a string, assume that's the id.
      clientId = clientMetadata
      clientMetadata = {}
    else
      clientId = clientMetadata.id
      delete clientMetadata.id

    id: App.BaseModel.coerceId(json.id)
    clientId: clientId
    clientMetadata: clientMetadata
    groupId: App.BaseModel.coerceId(json.group_id)
    oneToOneId: App.BaseModel.coerceId(json.one_to_one_id)
    userId: App.BaseModel.coerceId(json.user_id)
    mentionedUserIds: mentionedUserIds.map (id) -> App.BaseModel.coerceId(id)
    rank: json.rank ? parseInt(json.id)  # TODO: Remove json.id after upgrade.
    text: json.text
    imageUrl: json.image_url
    imageThumbUrl: json.image_thumb_url
    createdAt: api.deserializeUnixTimestamp(json.created_at)

  # This is different from the base class since it dedupes by client IDs.
  loadRawWithMetaData: (json) ->
    props = @propertiesFromRawAttrs(json)
    props.isLoaded ?= true

    prevInst = null
    prevInst = @_allById[props.id] if props.id?

    # This line is the client ID magic sauce.
    prevInst ?= @_allByClientId[props.clientId] if props.clientId?

    if prevInst?
      prevInst.setProperties(props)
      inst = prevInst
      isNew = false
    else
      inst = @create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst
      isNew = true

    [inst, isNew]

  discardRecords: (instances) ->
    # Remove from seen client IDs.
    for inst in instances when inst instanceof App.Message
      delete @_allByClientId[inst.get('clientId')]
    @_super(arguments...)

  # Given a Message instance, persists it to the server.  Returns a Promise.
  sendNewMessage: (message) ->
    data = {}
    for key in ['imageFile']
      val = message.get(key)
      if val?
        data[key.underscore()] = val

    # JSON encoded properties.
    data.client_metadata = JSON.stringify(message.get('clientId'))

    # Process text prior to sending over the wire.
    networkFacingText = message.get('networkFacingText')
    message.set('text', networkFacingText)
    if networkFacingText?
      data.text = networkFacingText

    mentionedUserIds = message.get('mentionedUserIds')
    if ! Ember.isEmpty(mentionedUserIds)
      data.mentioned_user_ids = mentionedUserIds.join(',')

    # Update instance state.
    message.set('isSaving', true)

    # Track the message's client ID.
    @_allByClientId[message.get('clientId')] = message

    # Only send message via POST if there's an image.
    convo = message.get('conversation')
    if message.get('imageFile')?
      api = App.get('api')
      formData = new FormData()
      formData.append(k, v) for k,v of api.defaultParams()
      formData.append(k, v) for k,v of data
      api.ajax(convo.publishMessageWithAttachmentUrl(), 'POST',
        data: formData
        processData: false
        contentType: false
      )
      .then (json) =>
        Ember.Logger.log "message create response", json
        message.set('isSaving', false)
        if ! json? || json.error?
          # Reject the promise.
          throw json

        json = Ember.makeArray(json)
        msgAttrs = json.find (o) -> o.object_type == 'message'
        @didCreateRecord(message, msgAttrs)

        return message
      , (xhr) =>
        message.set('isSaving', false)
        throw xhr.responseJSON
    else
      convo.willSendMessageToChannel(message, data)
      # Wrap Faye's promise in an RSVP.Promise.
      return new Ember.RSVP.Promise (resolve, reject) =>
        # Publish the message via the socket.
        App.get('fayeClient').publish(convo.publishMessageChannelName(), data)
        .then (result) =>
          Ember.run @, ->
            message.set('isSaving', false)
            resolve(result)
        , (error) =>
          Ember.run @, ->
            message.set('isSaving', false)
            reject(error)

  didCreateRecord: (message, attrs) ->
    hadId = message.get('id')?
    # Update the Message instance.
    props = @propertiesFromRawAttrs(attrs)
    # Update state.
    props.isLoaded = true
    props.isSaving = false
    message.setProperties(props)

    if ! hadId && message.get('id')?
      # Save to our identity map.
      @_all.pushObject(message)
      @_allById[message.get('id')] = message

  # Parses text and returns users from the given set who were mentioned.  This
  # is helpful when creating new messages.
  mentionedIdsInText: (text, users) ->
    return [] unless text?

    if /@all\b/i.test(text)
      # Everyone was mentioned.
      return [@mentionAllId]

    lowerCasedText = text.toLowerCase()
    users.filter (user) ->
      mentionName = user.get('mentionName')
      regexp = new RegExp("@#{App.Util.escapeRegexp(mentionName)}\\b", 'i')
      regexp.test(text)
    .mapProperty('id')
