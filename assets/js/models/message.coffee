#= require base-model

App.Message = App.BaseModel.extend

  # Error message to diplay to the user.
  errorMessage: null

  group: (->
    App.Group.lookup(@get('groupId'))
  ).property('groupId')

  user: (->
    App.User.lookup(@get('userId'))
  ).property('userId')

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
    userName = @get('user.name') ? "User #{@get('userId')}"
    roomName = @get('group.name') ? "Room #{@get('groupId')}"
    "#{userName} | #{roomName}"
  ).property('user.name', 'group.name')

  # This is the html text with emoticons and mentions.
  body: (->
    text = @get('text')

    escapedText = Ember.Handlebars.Utils.escapeExpression(text)

    # Link to URLs.  I know this looks overly complicated, but there's a reason.
    # We whitelist characters to prevent XSS injection.
    # See http://www.codinghorror.com/blog/2008/10/the-problem-with-urls.html
    urlRegexp = ///
      \(?                                # Optional open-paren at the beginning.
        \b(https?|ftp)://                # Protocol.
        [-A-Za-z0-9+&@\#/%?=~_()|!:,.;]* # Whitelist URL characters.
        [-A-Za-z0-9+&@\#/%=~_()|]        # Don't include punctuation at the end.
    ///g
    evaledText = escapedText.replace urlRegexp, (fullMatch) ->
      url = fullMatch
      prefix = ''
      suffix = ''
      if url[0] == '('
        if url.slice(-1) == ')'
          # The whole URL is inside parentheses.
          url = url[1 ... -1]
          prefix = '('
          suffix = ')'
        else
          url = url[1 ..]
          prefix = '('
      "#{prefix}<a href='#{url}' target='_blank'>#{url}</a>#{suffix}"

    # Mentions.
    currentUser = App.get('currentUser')
    group = @get('group')
    groupMembers = group.get('members')
    evaledText = evaledText.replace /@(\w+)/g, (fullMatch, name) ->
      user = App.User.userMentionedInGroup(name, groupMembers)
      isAll = /^all$/i.test(name)
      if user? || isAll
        classNames = ['mention']
        classNames.push('you') if user == currentUser || isAll
        "<span class='#{classNames.join(' ')}'>#{fullMatch}</span>"
      else
        fullMatch

    # Emoticons.
    evaledText = App.Emoticon.all().reduce (str, emoticon) ->
      regexp = new RegExp(App.Util.escapeRegexp(emoticon.get('name')), 'g')
      imageHtml = "<img class='emoticon' src='#{emoticon.get('imageUrl')}' title='#{emoticon.get('name')}'>"
      str.replace regexp, imageHtml
    , evaledText

    evaledText.htmlSafe()
  # Note: We omit group members' names from dependent keys since we don't care
  # about updating mentions when a user changes his/her name or a new user joins
  # or leaves the room.
  ).property('App.emoticonsVersion', 'text')

  isSentByCurrentUser: (->
    userId = @get('userId')
    userId? && userId == App.get('currentUser.id')
  ).property('userId', 'App.currentUser.id')

  loadAssociations: ->
    new Ember.RSVP.Promise (resolve, reject) =>
      user = App.User.lookup(@get('userId'))
      group = App.Group.lookup(@get('groupId'))
      if user? && ! Ember.isEmpty(group?.get('messages'))
        resolve(false)
      else
        App.Group.fetchById(@get('groupId'))
        .then (json) =>
          if json? && ! json.error?
            # Load everything from the response.
            instances = App.loadAll(json)

            group = instances.find (o) -> o instanceof App.Group
            group.didLoadMembers()
            newlyLoadedMessages = false
            if Ember.isEmpty(group.get('messages'))
              group.set('messages', instances.filter (o) -> o instanceof App.Message)
              newlyLoadedMessages = true

            resolve(newlyLoadedMessages)
            return true
          else
            throw new Error(JSON.stringify(json))

  toNotification: ->
    # TODO: icon field.
    tag: @get('groupId')
    title: @get('title')
    body: @get('text')
    icon: {}


App.Message.reopenClass

  # ID representing @all mention.  Yes, a string to match the type of other IDs.
  mentionAllId: '-1'

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  all: -> @_all

  loadRaw: (json) ->
    props = @propertiesFromRawAttrs(json)

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
    api = App.get('api')
    mentionedUserIds = if Ember.isArray(json.mentioned_user_ids)
      json.mentioned_user_ids
    else
      (json.mentioned_user_ids ? '').split(/,/)

    id: App.BaseModel.coerceId(json.id)
    groupId: App.BaseModel.coerceId(json.group_id)
    userId: App.BaseModel.coerceId(json.user_id)
    mentionedUserIds: mentionedUserIds.map (id) -> App.BaseModel.coerceId(id)
    text: json.text
    imageUrl: json.image_url
    imageThumbUrl: json.image_thumb_url
    createdAt: api.deserializeUnixTimestamp(json.created_at)

  # Given a Message instance, persists it to the server.  Returns a Promise.
  sendNewMessage: (message) ->
    groupId = message.get('groupId')
    data = {}
    for key in ['text', 'imageFile']
      val = message.get(key)
      if val?
        data[key.underscore()] = val

    mentionedUserIds = message.get('mentionedUserIds')
    if ! Ember.isEmpty(mentionedUserIds)
      data.mentioned_user_ids = mentionedUserIds.join(',')

    # Update instance state.
    message.set('isSaving', true)

    # Only send message via POST if there's an image.
    if message.get('imageFile')?
      api = App.get('api')
      formData = new FormData()
      formData.append(k, v) for k,v of api.defaultParams()
      formData.append(k, v) for k,v of data
      api.ajax(api.buildURL("/groups/#{groupId}/messages/create"), 'POST',
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
        else
          json = Ember.makeArray(json)
          msgAttrs = json.find (o) -> o.object_type == 'message'
          @didCreateRecord(message, msgAttrs)

          return message
      , (e) =>
        message.set('isSaving', false)
        throw e
    else
      # The instance is used by the faye extension.
      data.messageInstance = message
      # Wrap Faye's promise in an RSVP.Promise.
      return new Ember.RSVP.Promise (resolve, reject) =>
        # Publish the message via the socket.
        App.get('fayeClient').publish("/groups/#{groupId}/messages", data)
        .then (result) =>
          Ember.run @, ->
            message.set('isSaving', false)
            resolve(result)
        , (result) =>
          Ember.run @, ->
            message.set('isSaving', false)
            reject(result)

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
      name = user.get('name')
      mentionName = name.replace(/\s/g, '')
      regexp = new RegExp("@#{App.Util.escapeRegexp(mentionName)}\\b", 'i')
      regexp.test(text)
    .mapProperty('id')
